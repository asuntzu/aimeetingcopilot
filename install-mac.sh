#!/bin/bash
# AI Meeting Copilot — macOS installer (Apple Silicon or Intel, macOS 14.4+)
# Run from the repository folder:  ./install-mac.sh
set -euo pipefail
cd "$(dirname "$0")"
DIR="$(pwd)"
say() { printf "\n\033[1m%s\033[0m\n" "$*"; }

say "1/7  Checking requirements"
if ! command -v brew >/dev/null; then
  echo "Homebrew is required. Install it from https://brew.sh, then run this script again."; exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Apple's Command Line Tools are required. A window will open to install them; run this script again afterwards."
  xcode-select --install || true; exit 1
fi
OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1); OS_MINOR=$(sw_vers -productVersion | cut -d. -f2)
if (( OS_MAJOR < 14 || (OS_MAJOR == 14 && OS_MINOR < 4) )); then
  echo "macOS 14.4 or newer is needed to capture call audio. Transcription of your microphone will still work."
fi

say "2/7  Installing tools (ffmpeg, whisper.cpp, Node.js, uv, ripgrep)"
for pkg in ffmpeg whisper-cpp node uv ripgrep; do
  brew list --formula "$pkg" >/dev/null 2>&1 || brew install "$pkg"
done

say "3/7  Setting up Python packages"
uv venv --quiet --allow-existing --python 3.12 .venv
uv pip install --quiet --python .venv/bin/python -r requirements.txt
chmod 700 "$DIR"  # meetings, voiceprint and settings are private to you

say "4/7  Downloading speech models (about 210 MB, one time)"
mkdir -p models
# Download a file and refuse it unless its SHA-256 matches the known-good value.
fetch() {
  local url="$1" out="$2" sha="$3"
  if [ -f "$out" ] && [ "$(shasum -a 256 "$out" | cut -d' ' -f1)" = "$sha" ]; then return; fi
  curl -L --fail --proto '=https' --tlsv1.2 -o "$out.part" "$url"
  if [ "$(shasum -a 256 "$out.part" | cut -d' ' -f1)" != "$sha" ]; then
    rm -f "$out.part"; echo "SECURITY: $out failed its integrity check and was deleted. Try again later."; exit 1
  fi
  mv "$out.part" "$out"
}
fetch https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin \
  models/ggml-small.en-q5_1.bin bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30
fetch https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_resnet34.onnx \
  models/wespeaker_en_voxceleb_resnet34.onnx 5ef208a9da1453335308a6b6f4e6dfbd7e183a38b604de0a57664f45d257fe94

say "5/7  Building the call-audio helper and recorder app"
mkdir -p bin
swiftc -O mac/calltap.swift -o bin/calltap
APP="AI Meeting Copilot Recorder.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp mac/Info.plist "$APP/Contents/Info.plist"
swiftc -O mac/recorder.swift -o "$APP/Contents/MacOS/recorder"
codesign --force --sign - "$APP" >/dev/null
codesign --force --sign - bin/calltap >/dev/null

say "6/7  Your name"
CURRENT=$(.venv/bin/python -c "import json;print(json.load(open('config.json')).get('hostName',''))" 2>/dev/null || true)
read -r -p "How should your lines appear in transcripts? ${CURRENT:+[$CURRENT] }" NAME
NAME="${NAME:-${CURRENT:-Me}}"
HOST_NAME="$NAME" .venv/bin/python - <<'PY'
import json, os
p = "config.json"
cfg = json.load(open(p)) if os.path.exists(p) else {}
cfg.update({"hostName": os.environ["HOST_NAME"], "whisperCli": "whisper-cli", "whisperModel": "models/ggml-small.en-q5_1.bin"})
json.dump(cfg, open(p, "w"), indent=2)
PY

say "7/7  Connecting the helper to the Claude app"
NODE="$(command -v node)"
CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] && cp "$CFG" "$CFG.bak-ai-meeting-copilot"
NODE="$NODE" SERVER="$DIR/server.mjs" CFG="$CFG" .venv/bin/python - <<'PY'
import json, os
p = os.environ["CFG"]
cfg = json.load(open(p)) if os.path.exists(p) else {}
cfg.setdefault("mcpServers", {})["meeting-copilot"] = {"command": os.environ["NODE"], "args": [os.environ["SERVER"]]}
json.dump(cfg, open(p, "w"), indent=2)
PY
# Security: the helper is registered only with the Claude desktop app (which can ask you to confirm actions),
# not with Claude Code, so no coding session can start your microphone.

cat <<EOF

Done. Next steps:
  1. Quit and reopen the Claude desktop app.
  2. Publish your own copy of the page: open Claude Code in this folder and say
       Publish artifact/meeting-copilot.html as an artifact with the capabilities in artifact/capabilities.json
  3. Open it from Artifacts in the Claude app, go to Setup → Record my voice, then press Start.
     macOS will ask once to allow the microphone and system audio recording for "AI Meeting Copilot Recorder".
EOF
