// Captures everything your Mac is playing (Zoom, Meet, browser) without a virtual audio driver,
// using a Core Audio process tap. Writes 16 kHz mono float32 PCM to stdout until killed.
import AudioToolbox
import CoreAudio
import Foundation

func fail(_ msg: String, _ status: OSStatus = 0) -> Never {
  FileHandle.standardError.write("calltap: \(msg) (\(status))\n".data(using: .utf8)!)
  exit(1)
}

func prop<T>(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector, _ value: inout T) -> OSStatus {
  var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  var size = UInt32(MemoryLayout<T>.size)
  return AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value)
}

// Tap all system output except our own process, mixed down to stereo; the user still hears it.
var ownObj = AudioObjectID(kAudioObjectUnknown)
var pid = getpid()
var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var sz = UInt32(MemoryLayout<AudioObjectID>.size)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, UInt32(MemoryLayout<pid_t>.size), &pid, &sz, &ownObj)

let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: ownObj == kAudioObjectUnknown ? [] : [ownObj])
desc.uuid = UUID()
desc.muteBehavior = .unmuted
desc.isPrivate = true
var tapID = AudioObjectID(kAudioObjectUnknown)
var st = AudioHardwareCreateProcessTap(desc, &tapID)
if st != noErr { fail("could not create audio tap — allow System Audio Recording for Meeting Copilot Recorder", st) }

var outputUID: CFString = "" as CFString
var defaultOut = AudioObjectID(kAudioObjectUnknown)
_ = prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice, &defaultOut)
_ = prop(defaultOut, kAudioDevicePropertyDeviceUID, &outputUID)

let aggDesc: [String: Any] = [
  kAudioAggregateDeviceNameKey: "Meeting Copilot Tap",
  kAudioAggregateDeviceUIDKey: UUID().uuidString,
  kAudioAggregateDeviceMainSubDeviceKey: outputUID as String,
  kAudioAggregateDeviceIsPrivateKey: true,
  kAudioAggregateDeviceIsStackedKey: false,
  kAudioAggregateDeviceTapAutoStartKey: true,
  kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID as String]],
  kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: desc.uuid.uuidString]],
]
var aggID = AudioObjectID(kAudioObjectUnknown)
st = AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID)
if st != noErr { fail("could not create aggregate device", st) }

var fmt = AudioStreamBasicDescription()
_ = prop(tapID, kAudioTapPropertyFormat, &fmt)
let srcRate = fmt.mSampleRate > 0 ? fmt.mSampleRate : 48000
let channels = max(1, Int(fmt.mChannelsPerFrame))

// Downmix + resample (linear) to 16 kHz mono float32 on stdout.
let out = FileHandle.standardOutput
var phase = 0.0
let step = srcRate / 16000.0
var prev: Float = 0

var procID: AudioDeviceIOProcID?
st = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { _, inData, _, _, _ in
  let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
  guard let buf = abl.first, let raw = buf.mData else { return }
  let samples = raw.assumingMemoryBound(to: Float.self)
  let frames = Int(buf.mDataByteSize) / (MemoryLayout<Float>.size * channels)
  var outBuf = [Float]()
  outBuf.reserveCapacity(frames / Int(max(1, step)) + 2)
  for i in 0..<frames {
    var s: Float = 0
    for c in 0..<channels { s += samples[i * channels + c] }
    s /= Float(channels)
    // simple linear interpolation between prev and s
    while phase < 1.0 {
      outBuf.append(prev + (s - prev) * Float(phase))
      phase += step
    }
    phase -= 1.0
    prev = s
  }
  outBuf.withUnsafeBufferPointer { p in
    if let base = p.baseAddress { out.write(Data(bytes: base, count: p.count * MemoryLayout<Float>.size)) }
  }
}
if st != noErr { fail("could not create IO proc", st) }
st = AudioDeviceStart(aggID, procID)
if st != noErr { fail("could not start capture", st) }

func cleanup() {
  AudioDeviceStop(aggID, procID)
  if let procID { AudioDeviceDestroyIOProcID(aggID, procID) }
  AudioHardwareDestroyAggregateDevice(aggID)
  AudioHardwareDestroyProcessTap(tapID)
  exit(0)
}
var _sources: [DispatchSourceSignal] = []
signal(SIGPIPE, SIG_IGN)
for sig in [SIGINT, SIGTERM, SIGPIPE] {
  signal(sig, SIG_IGN)
  let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
  src.setEventHandler { cleanup() }
  src.resume()
  _sources.append(src)
}
RunLoop.main.run()
