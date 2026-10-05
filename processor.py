#!/usr/bin/env python3
"""AI Meeting Copilot transcription engine (macOS and Windows).

Records the microphone and the call audio (what Zoom / Meet / the browser is playing)
as separate streams in short chunks, transcribes each chunk locally with whisper.cpp,
labels microphone speech that matches the host's voiceprint with the host's name,
drops call audio that echoes into the mic, and appends lines like
"[10:02:13] Sam: ..." to live/transcript.md.

Audio chunks are deleted as soon as they are transcribed; only text is kept.

Usage:  processor.py <meeting-slug> [chunk-seconds]
        processor.py --enroll [seconds]      record the host's voiceprint (audio not kept)
Stop:   create live/stop.flag (the helper does this), or Ctrl-C.
"""
import datetime as dt
import difflib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import wave

import numpy as np

IS_WIN = sys.platform == "win32"
IS_MAC = sys.platform == "darwin"
DIR = os.path.dirname(os.path.abspath(__file__))
LIVE = os.path.join(DIR, "live")
CHUNKS = os.path.join(LIVE, "chunks")
OUT = os.path.join(LIVE, "transcript.md")
STOP = os.path.join(LIVE, "stop.flag")
PIDFILE = os.path.join(LIVE, "listen.pid")
ARCHIVE = os.path.join(DIR, "archive")
VOICE = os.path.join(DIR, "voice", "host.json")
ENROLL = os.path.join(LIVE, "enroll.json")
SPK_MODEL = os.path.join(DIR, "models", "wespeaker_en_voxceleb_resnet34.onnx")


def load_config():
    try:
        with open(os.path.join(DIR, "config.json"), encoding="utf-8-sig") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


CFG = load_config()
HOST = CFG.get("hostName") or "Me"
WHISPER_CLI = CFG.get("whisperCli") or ("whisper-cli.exe" if IS_WIN else "whisper-cli")
WHISPER_MODEL = os.path.join(DIR, CFG.get("whisperModel") or "models/ggml-small.en-q5_1.bin")
MIC = CFG.get("micDevice") or "default"
MATCH = float(CFG.get("voiceMatch", 0.45))  # cosine similarity needed to count as the host
SILENT_DB = -55.0
RATE = 16000
HALLUCINATIONS = re.compile(r"^(you|thank you\.?|thanks for watching!?|bye\.?|\.+|okay\.?)$", re.I)
os.makedirs(CHUNKS, exist_ok=True)
os.makedirs(ARCHIVE, exist_ok=True)


def log(msg):
    print(msg, flush=True)


# ---------- audio helpers ----------
def read_wav(path):
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0


def write_wav(path, a):
    tmp = path + ".part"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype(np.int16).tobytes())
    os.replace(tmp, path)


def peak_db(a):
    p = float(np.max(np.abs(a))) if a.size else 0.0
    return 20 * np.log10(p) if p > 0 else -91.0


def to_mono_16k(block, src_rate):
    a = block.mean(axis=1) if block.ndim > 1 else block
    if src_rate == RATE or not len(a):
        return a.astype(np.float32)
    n = int(len(a) * RATE / src_rate)
    return np.interp(np.linspace(0, len(a) - 1, n), np.arange(len(a)), a).astype(np.float32)


_extractor = None


def embed(a):
    global _extractor
    if _extractor is None:
        import sherpa_onnx
        _extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
            sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=SPK_MODEL, num_threads=2))
    s = _extractor.create_stream()
    s.accept_waveform(RATE, a)
    s.input_finished()
    e = np.array(_extractor.compute(s), dtype=np.float32)
    return e / (np.linalg.norm(e) or 1)


def whisper(path):
    """Return [(start_s, end_s, text)] segments."""
    base = path[:-4]
    flags = subprocess.CREATE_NO_WINDOW if IS_WIN else 0
    subprocess.run([WHISPER_CLI, "-m", WHISPER_MODEL, "-f", path, "-oj", "-of", base, "-np", "-nt"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)
    segs = []
    try:
        with open(base + ".json", encoding="utf-8") as f:
            data = json.load(f)
        for s in data.get("transcription", []):
            text = re.sub(r"\[[^\]]*\]|\([^)]*\)", "", s.get("text", "")).strip()
            if len(text) < 2 or HALLUCINATIONS.match(text):
                continue
            o = s.get("offsets", {})
            segs.append((o.get("from", 0) / 1000.0, o.get("to", 0) / 1000.0, text))
    except (OSError, ValueError):
        pass
    finally:
        try:
            os.remove(base + ".json")
        except OSError:
            pass
    return segs


def similar(a, b):
    return difflib.SequenceMatcher(None, a.lower().split(), b.lower().split()).ratio()


# ---------- capture backends ----------
class MacCapture:
    """ffmpeg (AVFoundation) for the mic, mac/calltap (Core Audio process tap) for call audio."""

    def __init__(self, chunk):
        self.chunk, self.procs, self.call_ok, self.note = chunk, [], False, ""

    def start(self):
        seg = ["-f", "segment", "-segment_time", str(self.chunk), "-reset_timestamps", "1", "-strftime", "1"]
        self.procs.append(subprocess.Popen(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "avfoundation", "-i", f":{MIC}",
             "-ac", "1", "-ar", str(RATE), *seg, os.path.join(CHUNKS, "mic_%H%M%S.wav")]))
        tap = subprocess.Popen([os.path.join(DIR, "bin", "calltap")], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        time.sleep(0.8)
        if tap.poll() is None:
            enc = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "f32le", "-ar", str(RATE),
                                    "-ac", "1", "-i", "-", *seg, os.path.join(CHUNKS, "sys_%H%M%S.wav")], stdin=tap.stdout)
            tap.stdout.close()
            self.procs += [tap, enc]
            self.call_ok = True
        else:
            self.note = tap.stderr.read().decode(errors="replace").strip()

    def alive(self):
        return self.procs[0].poll() is None

    def stop(self):
        for p in reversed(self.procs):
            if p.poll() is None:
                p.send_signal(signal.SIGINT)
        for p in self.procs:
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill()


class WinCapture:
    """WASAPI via the soundcard package: default microphone + loopback of the default speaker."""

    def __init__(self, chunk):
        self.chunk, self.threads, self.call_ok, self.note = chunk, [], False, ""
        self.running = True
        self.mic_ok = True

    def _record(self, device, prefix, flag):
        import soundcard  # Windows only
        src_rate = 48000
        try:
            with device.recorder(samplerate=src_rate, blocksize=src_rate // 10) as rec:
                buf, started = [], dt.datetime.now()
                while self.running:
                    buf.append(to_mono_16k(rec.record(numframes=src_rate // 2), src_rate))
                    if (dt.datetime.now() - started).total_seconds() >= self.chunk:
                        write_wav(os.path.join(CHUNKS, f"{prefix}_{started:%H%M%S}.wav"), np.concatenate(buf))
                        buf, started = [], dt.datetime.now()
                if buf:
                    write_wav(os.path.join(CHUNKS, f"{prefix}_{started:%H%M%S}.wav"), np.concatenate(buf))
        except Exception as e:  # noqa: BLE001 - surface any device error in the log
            setattr(self, flag, False)
            self.note = f"{prefix}: {e}"
            log(f"WARNING: {prefix} capture stopped ({e})")

    def start(self):
        import soundcard as sc
        mic = sc.default_microphone() if MIC == "default" else sc.get_microphone(MIC)
        self.threads.append(threading.Thread(target=self._record, args=(mic, "mic", "mic_ok"), daemon=True))
        try:
            loop = sc.get_microphone(id=str(sc.default_speaker().name), include_loopback=True)
            self.threads.append(threading.Thread(target=self._record, args=(loop, "sys", "call_ok"), daemon=True))
            self.call_ok = True
        except Exception as e:  # noqa: BLE001
            self.note = str(e)
        for t in self.threads:
            t.start()

    def alive(self):
        return self.mic_ok

    def stop(self):
        self.running = False
        for t in self.threads:
            t.join(timeout=3)


def record_mic(seconds):
    """Record the microphone for `seconds` and return 16 kHz mono float32 (never written to disk on Windows)."""
    if IS_WIN:
        import soundcard as sc
        mic = sc.default_microphone() if MIC == "default" else sc.get_microphone(MIC)
        data = mic.record(samplerate=48000, numframes=48000 * seconds)
        return to_mono_16k(data, 48000)
    tmp = tempfile.mkdtemp(prefix="amc-enroll-")
    wav = os.path.join(tmp, "voice.wav")
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "avfoundation", "-i", f":{MIC}",
                        "-t", str(seconds), "-ac", "1", "-ar", str(RATE), "-y", wav])
        return read_wav(wav)
    except Exception:  # noqa: BLE001
        return np.zeros(0, dtype=np.float32)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)  # never keep the recording


# ---------- enrollment ----------
def enroll(seconds=30):
    def status(**kw):
        with open(ENROLL, "w", encoding="utf-8") as f:
            json.dump(kw, f)

    status(state="recording", seconds=seconds, startedAt=time.time())
    a = record_mic(seconds)
    if a.size < RATE * 5:
        return status(state="error", error="Couldn't record from the microphone.")
    if peak_db(a) < SILENT_DB:
        return status(state="error", error="The microphone was silent. Check microphone permission for AI Meeting Copilot.")
    win, embs = RATE * 5, []
    for i in range(0, len(a) - win + 1, win // 2):
        w = a[i:i + win]
        if peak_db(w) > SILENT_DB + 10:
            embs.append(embed(w))
    if len(embs) < 2:
        return status(state="error", error="Not enough speech. Read the paragraph aloud at a normal volume.")
    E = np.stack(embs)
    v = E.mean(axis=0)
    v /= np.linalg.norm(v)
    os.makedirs(os.path.dirname(VOICE), exist_ok=True)
    with open(VOICE, "w", encoding="utf-8") as f:
        json.dump({"name": HOST, "embedding": [round(float(x), 6) for x in v],
                   "created": dt.datetime.now().isoformat(), "consistency": round(float(np.mean(E @ v)), 3)}, f)
    status(state="done")


# ---------- live transcription ----------
class Session:
    def __init__(self, name, chunk):
        self.name, self.chunk = name, chunk
        self.stamp = dt.datetime.now().strftime("%Y-%m-%d_%H%M")
        self.host = None
        if os.path.exists(VOICE):
            with open(VOICE, encoding="utf-8") as f:
                self.host = np.array(json.load(f)["embedding"], dtype=np.float32)
        self.last_mic_label = HOST if self.host is None else None
        self.capture = (WinCapture if IS_WIN else MacCapture)(chunk)
        self.stopping = False

    def start(self):
        for f in os.listdir(CHUNKS):
            os.remove(os.path.join(CHUNKS, f))
        for f in (STOP,):
            if os.path.exists(f):
                os.remove(f)
        if os.path.exists(OUT) and os.path.getsize(OUT):
            prev = dt.datetime.fromtimestamp(os.path.getmtime(OUT)).strftime("%Y-%m-%d_%H%M")
            shutil.move(OUT, os.path.join(ARCHIVE, f"{prev}-previous.md"))
        with open(OUT, "w", encoding="utf-8") as f:
            f.write(f"# {self.name} — {self.stamp}\n")
        self.capture.start()
        with open(PIDFILE, "w") as f:
            f.write(str(os.getpid()))
        log("Capturing mic + call audio" if self.capture.call_ok
            else f"WARNING: call audio unavailable ({self.capture.note}) — capturing mic only")
        log(f"Listening… voice profile: {'yes' if self.host is not None else 'no'}")

    def ready(self, final=False):
        files = sorted(os.listdir(CHUNKS))
        mic = [f for f in files if f.startswith("mic_") and f.endswith(".wav")]
        sys_ = [f for f in files if f.startswith("sys_") and f.endswith(".wav")]
        if not final and not IS_WIN:
            mic, sys_ = mic[:-1], sys_[:-1]  # ffmpeg is still writing the newest chunk
        return mic, sys_

    @staticmethod
    def t0(fname):
        return dt.datetime.combine(dt.date.today(), dt.datetime.strptime(fname[4:10], "%H%M%S").time())

    def process(self, final=False):
        mic, sys_ = self.ready(final)
        if not mic and not sys_:
            return
        if self.capture.call_ok and not final and mic and not sys_:
            age = (dt.datetime.now() - self.t0(mic[0])).total_seconds()
            # Call audio only produces chunks while something is playing, so wait a few seconds
            # for the matching call chunk (used to drop speaker echo), then carry on without it.
            if age < self.chunk + 6:
                return
        batch_mic = mic[:1]
        start = self.t0(batch_mic[0]) if batch_mic else self.t0(sys_[0])
        end = start + dt.timedelta(seconds=self.chunk + 1)
        batch_sys = [f for f in sys_ if self.t0(f) < end] if batch_mic else sys_[:1]
        lines, call_text = [], []
        for f in batch_sys:
            path = os.path.join(CHUNKS, f)
            a = read_wav(path)
            lvl = peak_db(a)
            self.write_level("sys", lvl)
            if lvl > SILENT_DB:
                for s, e, text in whisper(path):
                    at = self.t0(f) + dt.timedelta(seconds=s)
                    lines.append((at, "Call", text))
                    call_text.append((at, text))
            os.remove(path)
        for f in batch_mic:
            path = os.path.join(CHUNKS, f)
            a = read_wav(path)
            lvl = peak_db(a)
            self.write_level("mic", lvl)
            if lvl > SILENT_DB:
                for s, e, text in whisper(path):
                    at = self.t0(f) + dt.timedelta(seconds=s)
                    label = self.label_mic(a, s, e, text, at, call_text)
                    if label:
                        lines.append((at, label, text))
            os.remove(path)
        lines.sort(key=lambda x: x[0])
        if lines:
            with open(OUT, "a", encoding="utf-8") as fh:
                for at, who, text in lines:
                    fh.write(f"[{at:%H:%M:%S}] {who}: {text}\n")

    def label_mic(self, a, s, e, text, at, call_text):
        for ct_at, ct in call_text:  # the call echoing through the speakers into the mic
            if abs((ct_at - at).total_seconds()) < self.chunk and similar(text, ct) > 0.5:
                return None
        if self.host is None:
            return HOST
        seg = a[int(s * RATE):int(e * RATE)]
        if len(seg) >= RATE:
            sim = float(embed(seg) @ self.host)
            self.last_mic_label = HOST if sim >= MATCH else ("Echo" if call_text else "Guest")
        label = self.last_mic_label or "Guest"
        return None if label == "Echo" else label

    def write_level(self, which, db):
        path = os.path.join(LIVE, "level.json")
        try:
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
        except (OSError, ValueError):
            d = {}
        d[which] = {"db": round(db, 1), "at": time.time()}
        d["callCapture"] = self.capture.call_ok
        with open(path, "w", encoding="utf-8") as f:
            json.dump(d, f)

    def stop(self, *_):
        self.stopping = True

    def run(self):
        signal.signal(signal.SIGINT, self.stop)
        signal.signal(signal.SIGTERM, self.stop)
        self.start()
        while not self.stopping and not os.path.exists(STOP):
            if not self.capture.alive():
                log("ERROR: microphone capture stopped unexpectedly")
                break
            self.process()
            time.sleep(1.5)
        self.capture.stop()
        while self.ready(final=True) != ([], []):
            self.process(final=True)
        shutil.copy(OUT, os.path.join(ARCHIVE, f"{self.stamp}-{self.name}.md"))
        for f in (PIDFILE, STOP):
            try:
                os.remove(f)
            except OSError:
                pass
        log(f"Saved: {os.path.join(ARCHIVE, f'{self.stamp}-{self.name}.md')}")


def safe_slug(name):
    """Meeting names end up in file names: keep them to letters, digits and dashes."""
    return re.sub(r"[^a-z0-9]+", "-", str(name).lower()).strip("-")[:60] or "meeting"


if __name__ == "__main__":
    if not IS_WIN:
        os.umask(0o077)  # transcripts and the voiceprint are readable only by you
    if IS_MAC:
        os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + os.environ.get("PATH", "")
    if len(sys.argv) > 1 and sys.argv[1] == "--enroll":
        secs = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 30
        enroll(min(60, max(15, secs)))
    else:
        chunk = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 20
        Session(safe_slug(sys.argv[1] if len(sys.argv) > 1 else "meeting"), min(60, max(10, chunk))).run()
