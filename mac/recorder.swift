// macOS launcher that owns the microphone and audio-capture permissions, then runs processor.py.
import AVFoundation
import Foundation

let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
  .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let live = dir.appendingPathComponent("live")
let log = live.appendingPathComponent("listen.log")
try? FileManager.default.createDirectory(at: live, withIntermediateDirectories: true)
FileManager.default.createFile(atPath: log.path, contents: nil)
let logHandle = try! FileHandle(forWritingTo: log)

var decided = false, granted = false
switch AVCaptureDevice.authorizationStatus(for: .audio) {
case .authorized: granted = true; decided = true
case .notDetermined: AVCaptureDevice.requestAccess(for: .audio) { g in granted = g; decided = true }
default: decided = true
}
while !decided { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
if !granted {
  logHandle.write("ERROR: microphone access denied. Turn on AI Meeting Copilot Recorder in System Settings → Privacy & Security → Microphone.\n".data(using: .utf8)!)
  exit(2)
}

let p = Process()
p.executableURL = dir.appendingPathComponent(".venv/bin/python")
p.arguments = ["-u", dir.appendingPathComponent("processor.py").path] + CommandLine.arguments.dropFirst()
var env = ProcessInfo.processInfo.environment
env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
p.environment = env
p.currentDirectoryURL = dir
p.standardOutput = logHandle
p.standardError = logHandle
for sig in [SIGINT, SIGTERM] {
  signal(sig, SIG_IGN)
  let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
  src.setEventHandler { if p.isRunning { kill(p.processIdentifier, SIGINT) } }
  src.resume()
  objc_setAssociatedObject(p, "\(sig)", src, .OBJC_ASSOCIATION_RETAIN)
}
p.terminationHandler = { proc in exit(proc.terminationStatus) }
try! p.run()
RunLoop.main.run()
