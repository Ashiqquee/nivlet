// Website media only. Never targets the production app, clipboard or library.
// macOS 15+ capture helper; this does not change Nivlet's macOS 14 floor.
import AppKit
import ApplicationServices
import ScreenCaptureKit
import AVFoundation

let mediaBundle = "ashique.nivlet.phase8media"

@MainActor
final class Demo {
    let app: NSRunningApplication
    let root: AXUIElement
    init() {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: mediaBundle).first else {
            fatalError("Launch the isolated Phase8Media app with -NivletPreview YES first")
        }
        app = running; root = AXUIElementCreateApplication(running.processIdentifier)
    }
    func value(_ element: AXUIElement, _ key: String) -> Any? {
        var result: CFTypeRef?
        AXUIElementCopyAttributeValue(element, key as CFString, &result)
        return result
    }
    func descendants(_ element: AXUIElement) -> [AXUIElement] {
        [element] + (value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap(descendants)
    }
    var elements: [AXUIElement] {
        (value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []).flatMap(descendants)
    }
    func find(_ label: String) -> AXUIElement? {
        elements.first { value($0, kAXDescriptionAttribute) as? String == label || value($0, kAXTitleAttribute) as? String == label }
    }
    func pause(_ seconds: Double = 0.5) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    func press(_ label: String) async {
        guard let element = find(label) else { fatalError("Missing native control: \(label)") }
        let status = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard status == .success || status == .cannotComplete else { fatalError("Cannot press \(label): \(status)") }
        await pause()
    }
    func key(_ code: CGKeyCode, flags: CGEventFlags = []) async {
        app.activate(); await pause(0.1)
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == mediaBundle else { fatalError("Capture app lost focus") }
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
            event.flags = flags; event.post(tap: .cghidEventTap)
        }
        await pause()
    }
    func fill(_ label: String, _ text: String) async {
        guard let field = find(label) else { fatalError("Missing sample field: \(label)") }
        app.activate(); await pause(0.1)
        guard AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else { fatalError("Cannot focus \(label)") }
        await key(0, flags: .maskCommand)
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == mediaBundle else { fatalError("Capture app lost focus") }
        for character in text {
            let chars = Array(String(character).utf16)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                event.post(tap: .cghidEventTap)
            }
            await pause(0.035)
        }
        await pause(0.7)
    }
    func screenshot(_ path: String) throws {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let window = windows.first(where: {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier &&
            (($0[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) > 300
        }), let id = window[kCGWindowNumber as String] as? CGWindowID else { fatalError("No sample panel") }
        let capture = Process(); capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(id), path]
        try capture.run(); capture.waitUntilExit()
        guard capture.terminationStatus == 0 else { fatalError("Window capture failed") }
    }
    func scenes(folder: String) async throws {
        if find("Pin panel") != nil { await press("Pin panel") }
        await pause(2)
        try screenshot(folder + "/prompts.png"); await pause(1.5)
        await press("Explain a concept"); await pause(1)
        await fill("Topic", "design systems")
        await fill("Audience", "a new teammate")
        let visible = elements.compactMap { value($0, kAXValueAttribute) as? String }.joined(separator: "\n")
        guard visible.contains("2 of 2 filled") else { fatalError("Native template did not render both values") }
        try screenshot(folder + "/fill-in-prompt.png"); await pause(2)
        await key(53); await key(19, flags: .maskCommand)
        try screenshot(folder + "/references.png"); await pause(2)
        await key(20, flags: .maskCommand)
        try screenshot(folder + "/scratchpad.png"); await pause(2)
        await key(18, flags: .maskCommand)
        // No Copy action: preview mode has no private transfer pasteboard.
        await pause(1)
    }
}

final class Recorder: NSObject, SCRecordingOutputDelegate {
    let lock = NSLock()
    private var complete = false
    private var failure: Error?
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        lock.lock(); complete = true; lock.unlock()
    }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        lock.lock(); failure = error; complete = true; lock.unlock()
    }
    func state() -> (Bool, Error?) { lock.lock(); defer { lock.unlock() }; return (complete, failure) }
}

@main
struct Capture {
    @MainActor static func main() async throws {
        guard #available(macOS 15, *) else { fatalError("Media recording needs macOS 15+") }
        if Array(CommandLine.arguments.dropFirst()) == ["--quit"] {
            guard Demo().app.terminate() else { fatalError("Cannot quit isolated capture app") }
            return
        }
        guard CommandLine.arguments.count == 2 else { fatalError("Use capture_phase8_media <new-output-directory>") }
        let folder = CommandLine.arguments[1]
        guard !FileManager.default.fileExists(atPath: folder) else { fatalError("Preserve existing media; use a new output folder") }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let demo = Demo()
        demo.app.activate()
        await demo.pause(1)
        if demo.find("Pin panel") == nil && demo.find("Unpin panel") == nil {
            await demo.press("Open Nivlet")
        }
        let shareable = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = shareable.windows.first(where: { $0.owningApplication?.bundleIdentifier == mediaBundle && $0.frame.width > 300 }) else {
            fatalError("No isolated sample panel to record")
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * 2); config.height = Int(window.frame.height * 2)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.capturesAudio = false; config.showsCursor = false
        let recorder = Recorder()
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = URL(fileURLWithPath: folder + "/native-demo.mp4")
        recording.videoCodecType = .h264; recording.outputFileType = .mp4
        let recordingOutput = SCRecordingOutput(configuration: recording, delegate: recorder)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addRecordingOutput(recordingOutput)
        try await stream.startCapture()
        await demo.pause(1)
        try await demo.scenes(folder: folder)
        do { try await stream.stopCapture() }
        catch {
            let streamError = error as NSError
            guard streamError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain", streamError.code == -3808 else { throw error }
            print("Stream already stopped; checking the recording delegate's completion before accepting media.")
        }
        for _ in 0..<100 {
            if recorder.state().0 { break }; await demo.pause(0.1)
        }
        let (finished, error) = recorder.state()
        if let error { throw error }
        guard finished else { fatalError("Recording did not finish") }
        print("Captured only native sample window: \(config.width) × \(config.height), 30 fps, no audio. No clipboard writes.")
    }
}
