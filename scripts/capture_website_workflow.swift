// Website media harness. Targets only the isolated websiteworkflow build.
// Uses an unsent Codex draft and synthetic Nivlet library. No working pockets or model requests.
// General clipboard contents are preserved in memory and restored if still owned.
// swiftc -parse-as-library -swift-version 5 ... -o build/capture-website-workflow
import AppKit
import ApplicationServices
import AVFoundation
import ScreenCaptureKit
import SQLite3
import CryptoKit

let demoBundle = "ashique.nivlet.websiteworkflow"
let demoBoard = "nivlet-verification-website-demo-v1"

struct CaptureFailure: Error { let message: String; init(_ message: String) { self.message = message } }

struct Prompt: Codable { let title: String; let text: String }

@MainActor func pause(_ seconds: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}
@MainActor func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255, alpha: 1)
}
@MainActor func box(_ rect: CGRect, _ fill: UInt32, _ radius: CGFloat = 0) {
    color(fill).setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
@MainActor func text(_ string: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 14,
                     _ fill: UInt32 = 0xececee, _ weight: NSFont.Weight = .regular) {
    (string as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color(fill)])
}
@MainActor func makeReference(_ url: URL) throws {
    let image = NSImage(size: NSSize(width: 1040, height: 760), flipped: true) { _ in
        box(CGRect(x: 0, y: 0, width: 1040, height: 760), 0xf7f8fa)
        box(CGRect(x: 0, y: 0, width: 230, height: 760), 0xeceef2)
        box(CGRect(x: 24, y: 29, width: 30, height: 30), 0x28332e, 9)
        text("n", 33, 30, 22, 0xe4efc1, .semibold); text("Northstar", 66, 34, 19, 0x27332d, .semibold)
        text("WORKSPACE", 28, 105, 11, 0x747d78, .semibold)
        for (i, label) in ["Overview", "Projects", "Reference library", "Archive"].enumerated() {
            if i == 1 { box(CGRect(x: 16, y: 171, width: 198, height: 42), 0xdce2d8, 9) }
            text(["◈", "▦", "▧", "□"][i], 30, CGFloat(143 + i * 45), 16, 0x61735a)
            text(label, 61, CGFloat(143 + i * 45), 14, 0x35413a, i == 1 ? .semibold : .regular)
        }
        text("PINNED PROJECTS", 28, 362, 11, 0x747d78, .semibold)
        text("●   Website launch", 30, 402, 14, 0x35413a); text("●   Design system", 30, 443, 14, 0x66756c)
        text("AK", 31, 704, 14, 0x35413a, .semibold); text("Alex Kim", 66, 704, 14, 0x35413a)
        text("Projects  /  Website launch", 270, 38, 13, 0x7a827e)
        text("Website launch", 270, 108, 32, 0x28332e, .semibold)
        text("A little more focus. A little less friction.", 272, 158, 16, 0x7a827e)
        box(CGRect(x: 866, y: 111, width: 130, height: 36), 0x293b32, 9); text("+  Add task", 886, 120, 13, 0xffffff, .medium)
        text("Board", 274, 228, 14, 0x28332e, .semibold); text("Timeline", 356, 228, 14, 0x8b918d)
        box(CGRect(x: 270, y: 259, width: 724, height: 1), 0xe1e4e1)
        for (i, heading) in ["To do    3", "In progress    2", "Done    4"].enumerated() {
            let x = CGFloat(270 + i * 246)
            text(heading, x, 292, 13, 0x6e7972, .semibold)
            for j in 0..<2 {
                let y = CGFloat(334 + j * 148)
                box(CGRect(x: x, y: y, width: 230, height: 129), 0xffffff, 12)
                box(CGRect(x: x + 14, y: y + 15, width: 64, height: 21), i == 1 ? 0xffecd9 : 0xe9eedc, 5)
                text(i == 1 ? "REVIEW" : "DESIGN", x + 22, y + 20, 9, 0x6c735d, .semibold)
                let titles = [["Polish the navigation", "Refine empty states"], ["Review mobile layouts", "Check keyboard flow"], ["Define type scale", "Choose the palette"]]
                text(titles[i][j], x + 14, y + 52, 14, 0x34423a, .medium)
                text("Website launch", x + 14, y + 77, 11, 0x9aa29c)
                text("◷  Nov 6                         AK", x + 14, y + 104, 10, 0x7a867e)
            }
        }
        return true
    }
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: url, options: .withoutOverwriting)
}

@MainActor final class Driver {
    let app: NSRunningApplication
    let root: AXUIElement
    init(bundle: String = demoBundle) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { fatalError("Launch \(bundle) first") }
        self.app = app; root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(root, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(root, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }
    func value(_ e: AXUIElement, _ key: String) -> Any? {
        var value: CFTypeRef?; AXUIElementCopyAttributeValue(e, key as CFString, &value); return value
    }
    func descendants(_ e: AXUIElement) -> [AXUIElement] {
        [e] + (value(e, kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap(descendants)
    }
    var elements: [AXUIElement] { (value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []).flatMap(descendants) }
    func find(_ label: String) -> AXUIElement? {
        elements.first { value($0, kAXDescriptionAttribute) as? String == label || value($0, kAXTitleAttribute) as? String == label }
    }
    func bounds(_ e: AXUIElement) -> CGRect {
        var point = CGPoint.zero; var size = CGSize.zero
        AXValueGetValue(value(e, kAXPositionAttribute) as! AXValue, .cgPoint, &point)
        AXValueGetValue(value(e, kAXSizeAttribute) as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
    func press(_ label: String) async throws {
        guard let e = find(label) else { throw CaptureFailure("Missing control: \(label)") }
        // Move the real pointer to the activated control, without a fabricated overlay.
        let b = bounds(e)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: b.midX, y: b.midY), mouseButton: .left)?.post(tap: .cghidEventTap)
        await pause(0.3)
        let status = AXUIElementPerformAction(e, kAXPressAction as CFString)
        guard status == .success || status == .cannotComplete else { throw CaptureFailure("Cannot press \(label)") }
        await pause(0.55)
    }
    func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) async throws {
        app.activate(); await pause(0.2)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw CaptureFailure("Target app lost focus") }
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
            e.flags = flags; e.post(tap: .cghidEventTap)
        }
        await pause(0.5)
    }
}

final class Recording: NSObject, SCRecordingOutputDelegate {
    private let lock = NSLock()
    private var done = false
    private var error: Error?
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { lock.lock(); done = true; lock.unlock() }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { lock.lock(); self.error = error; done = true; lock.unlock() }
    func state() -> (Bool, Error?) { lock.lock(); defer { lock.unlock() }; return (done, error) }
}

@main struct WorkflowCapture {
    @MainActor static func main() async throws {
        guard #available(macOS 15, *) else { throw CaptureFailure("Recording helper requires macOS 15 or later") }
        guard CommandLine.arguments.count == 3 else { fatalError("Use prepare <fixtures-folder> or record <new-output-folder>") }
        let mode = CommandLine.arguments[1], folder = URL(fileURLWithPath: CommandLine.arguments[2])
        if mode == "inspect-codex" || mode == "inspect-native" {
            let driver = Driver(bundle: mode == "inspect-native" ? demoBundle : "com.openai.codex")
            driver.app.activate(); await pause(0.8)
            print("Accessibility trusted: \(AXIsProcessTrusted()), pid: \(driver.app.processIdentifier), windows: \((driver.value(driver.root, kAXWindowsAttribute) as? [AXUIElement] ?? []).count)")
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            for w in content.windows where ["com.openai.codex", demoBundle].contains(w.owningApplication?.bundleIdentifier ?? "") {
                print("Capture window \(w.windowID): \(w.frame), bundle \(w.owningApplication?.bundleIdentifier ?? "")")
            }
            if CommandLine.arguments[2] == "new" { try await driver.press("New chat") }
            for e in driver.elements {
                let role = driver.value(e, kAXRoleAttribute) as? String ?? ""
                if ["AXButton", "AXTextField", "AXTextArea", "AXMenuButton", "AXPopUpButton"].contains(role) {
                    let label = driver.value(e, kAXDescriptionAttribute) as? String ?? driver.value(e, kAXTitleAttribute) as? String ?? ""
                    let b = driver.bounds(e)
                    print("\(role) \(label) [\(Int(b.minX)),\(Int(b.minY)),\(Int(b.width)),\(Int(b.height))]")
                }
            }
            return
        }
        if mode == "prepare" {
            // Only the new isolated app's explicitly named synthetic library.
            let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Containers/\(demoBundle)/Data/Library/Application Support/ashique.nivlet.Nivlet/verification-website-demo-v1")
            guard FileManager.default.fileExists(atPath: root.appending(path: "library.sqlite").path) else { fatalError("Launch isolated app once first: \(root.path)") }
            let driver = Driver(); guard driver.app.terminate() else { fatalError("Cannot quit demo app") }
            for _ in 0..<50 { if driver.app.isTerminated { break }; await pause(0.1) }
            guard driver.app.isTerminated else { fatalError("Demo app still running") }
            if !FileManager.default.fileExists(atPath: folder.appending(path: "Sidebar layout.png").path) {
                try makeReference(folder.appending(path: "Sidebar layout.png"))
            }
            let reference = try Data(contentsOf: folder.appending(path: "Sidebar layout.png"))
            let digest = SHA256.hash(data: reference).map { String(format: "%02x", $0) }.joined()
            let asset = root.appending(path: "assets/\(digest)")
            try FileManager.default.createDirectory(at: asset, withIntermediateDirectories: true)
            try reference.write(to: asset.appending(path: "original"), options: .withoutOverwriting)
            let prompts = try JSONDecoder().decode([Prompt].self, from: Data(contentsOf: folder.appending(path: "prompts.json")))
            var db: OpaquePointer?; guard sqlite3_open(root.appending(path: "library.sqlite").path, &db) == SQLITE_OK else { fatalError("Cannot seed demo") }
            defer { sqlite3_close(db) }
            var query: OpaquePointer?; sqlite3_prepare_v2(db, "SELECT count(*) FROM text_items", -1, &query, nil); sqlite3_step(query)
            let count = sqlite3_column_int(query, 0); sqlite3_finalize(query)
            guard count == 0 else { fatalError("Refusing to replace populated demo library") }
            func sql(_ sql: String) { guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { fatalError(String(cString: sqlite3_errmsg(db))) } }
            func quoted(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "''") + "'" }
            sql("BEGIN IMMEDIATE; UPDATE pockets SET name='Website launch';")
            for (i, prompt) in prompts.enumerated() {
                sql("INSERT INTO text_items SELECT '\(UUID().uuidString)',id,'prompt',\(quoted(prompt.title)),\(quoted(prompt.text)),0,\(i),0 FROM pockets LIMIT 1")
            }
            sql("INSERT INTO reference_items SELECT '\(UUID().uuidString)',id,'Sidebar layout','A navigation and layout reference for the launch.','Sidebar layout.png','\(digest)',1,0,0,\(reference.count) FROM pockets LIMIT 1")
            sql("COMMIT")
            print("Prepared synthetic prompts and original sidebar reference; no production data touched."); return
        }
        guard mode == "record", !FileManager.default.fileExists(atPath: folder.path) else { fatalError("Use record with a new output directory") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let driver = Driver()
        for _ in 0..<40 {
            if driver.find("Open Nivlet") != nil || driver.find("Pin panel") != nil || driver.find("Unpin panel") != nil { break }
            await pause(0.2)
        }
        if driver.find("Open Nivlet") != nil { try await driver.press("Open Nivlet") }
        if driver.find("Pin panel") != nil { try await driver.press("Pin panel") }
        guard driver.find("Unpin panel") != nil else { throw CaptureFailure("Pin demo panel before capture") }
        if driver.find("Cancel") != nil { try await driver.press("Cancel") }
        if driver.find("Copy prompt") != nil { try await driver.press("Prompts") }
        try await driver.press("Prompts")
        let codex = Driver(bundle: "com.openai.codex")
        codex.app.activate(); await pause(1)
        let initialContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let codexWindow = initialContent.windows.first(where: { $0.owningApplication?.processID == codex.app.processIdentifier && $0.frame.width > 500 && $0.frame.height > 300 }) else { throw CaptureFailure("No visible Codex window") }
        let frame = codexWindow.frame
        func click(_ point: CGPoint) async {
            for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
                await pause(0.1)
            }
        }
        codex.app.activate(); await pause(0.8)
        if codex.find("Don't work in a project") != nil { try await codex.press("Don't work in a project") }
        if codex.find("Hide sidebar") != nil { try await codex.press("Hide sidebar") }
        // Deliberately require a fresh visible draft. Do not assume a shortcut
        // clears a draft, move Spaces, or discard a person's existing work.
        guard let initialComposer = codex.find("Do anything"),
              let initialValue = codex.value(initialComposer, kAXValueAttribute) as? String,
              initialValue.isEmpty else { throw CaptureFailure("Choose New chat in Codex before recording; the demo must start with an empty draft") }
        let prompts = try JSONDecoder().decode([Prompt].self, from: Data(contentsOf: URL(fileURLWithPath: "website/artwork/workflow-demo/prompts.json")))
        let board = NSPasteboard.general
        // Preserve the user's clipboard only in memory and restore if no other app
        // has replaced it. Never log or persist any of its contents.
        let previousItems = (board.pasteboardItems ?? []).map { original -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for type in original.types { if let data = original.data(forType: type) { item.setData(data, forType: type) } }
            return item
        }
        var ownedChangeCount = board.changeCount
        defer {
            if board.changeCount == ownedChangeCount {
                board.clearContents(); if !previousItems.isEmpty { board.writeObjects(previousItems) }
            }
        }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let windows = content.windows.filter { ($0.owningApplication?.processID == driver.app.processIdentifier || $0.owningApplication?.processID == codex.app.processIdentifier) && $0.frame.width > 100 && $0.frame.height > 100 }
        guard windows.count >= 2, let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { throw CaptureFailure("Missing Codex or Nivlet window") }
        let filter = SCContentFilter(display: display, including: windows)
        let config = SCStreamConfiguration(); config.width = display.width * 2; config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30); config.capturesAudio = false; config.showsCursor = true
        let recorder = Recording(), output = SCRecordingOutputConfiguration()
        output.outputURL = folder.appending(path: "workflow-source.mp4"); output.videoCodecType = .h264; output.outputFileType = .mp4
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addRecordingOutput(SCRecordingOutput(configuration: output, delegate: recorder))
        try await stream.startCapture()
        let start = Date(); var marks: [[String: Any]] = []
        func mark(_ title: String) { let t = Date().timeIntervalSince(start); marks.append(["title": title, "time": t]); print(String(format: "%.2f %@", t, title)) }
        mark("Saved prompts"); await pause(2)
        try await driver.press(prompts[0].title); await pause(2)
        mark("Copy prompt"); try await driver.press("Copy prompt")
        ownedChangeCount = board.changeCount
        guard board.string(forType: .string) == prompts[0].text else { throw CaptureFailure("Exact copy verification failed; launch Nivlet with general pasteboard") }
        await pause(0.8)
        guard let composer = codex.find("Do anything") else { throw CaptureFailure("No empty Codex composer") }
        let composerBounds = codex.bounds(composer)
        let composerPoint = CGPoint(x: composerBounds.midX, y: composerBounds.midY)
        await click(composerPoint)
        mark("Paste into Codex"); try await codex.key(9, .maskCommand)
        await pause(2)
        // Copy the composer selection back to verify the actual pasted text.
        try await codex.key(0, .maskCommand); try await codex.key(8, .maskCommand)
        ownedChangeCount = board.changeCount
        guard board.string(forType: .string) == prompts[0].text else { throw CaptureFailure("Codex paste differs from saved prompt") }
        try await codex.key(124); await pause(1)
        try await driver.press("Prompts"); try await driver.press(prompts[1].title)
        mark("Launch QA prompt"); await pause(2.4); try await driver.press("Copy prompt")
        ownedChangeCount = board.changeCount
        guard board.string(forType: .string) == prompts[1].text else { throw CaptureFailure("QA copy differs") }
        mark("Paste launch QA into Codex")
        await click(composerPoint); try await codex.key(0, .maskCommand); try await codex.key(9, .maskCommand)
        await pause(2)
        try await codex.key(0, .maskCommand); try await codex.key(8, .maskCommand)
        ownedChangeCount = board.changeCount
        guard board.string(forType: .string) == prompts[1].text else { throw CaptureFailure("QA paste differs") }
        try await codex.key(124); await pause(1)
        try await driver.press("Prompts"); try await driver.press("References")
        mark("UI reference"); await pause(2.2)
        guard let thumbnail = driver.find("Preview Sidebar layout") else { throw CaptureFailure("Missing reference thumbnail") }
        let source = driver.bounds(thumbnail)
        let destination = CGPoint(x: composerBounds.midX, y: composerBounds.midY)
        let origin = CGPoint(x: source.midX, y: source.midY)
        mark("Drag reference")
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: origin, mouseButton: .left)?.post(tap: .cghidEventTap); await pause(0.4)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: origin, mouseButton: .left)?.post(tap: .cghidEventTap); await pause(0.3)
        for step in 1...50 {
            let fraction = CGFloat(step) / 50
            let point = CGPoint(x: origin.x + (destination.x - origin.x) * fraction, y: origin.y + (destination.y - origin.y) * fraction)
            CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            await pause(0.025)
        }
        await pause(0.5)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: destination, mouseButton: .left)?.post(tap: .cghidEventTap)
        mark("Check attachment in Codex"); await pause(6)
        try await stream.stopCapture()
        for _ in 0..<100 { if recorder.state().0 { break }; await pause(0.1) }
        if let error = recorder.state().1 { throw error }
        guard recorder.state().0 else { throw CaptureFailure("Recording did not finish") }
        let report: [String: Any] = ["bundle": demoBundle, "source": "workflow-source.mp4", "screen": [display.width, display.height], "codex_frame": [frame.minX, frame.minY, frame.width, frame.height], "marks": marks, "exact_prompt_copy_and_paste": true, "general_clipboard_restored_if_unchanged": true, "receiver": "Actual open Codex desktop app (com.openai.codex); explicit Command-V; real pointer file drag; nothing sent"]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appending(path: "capture.json"))
        print("PASS: exact prompt copy and paste into actual Codex; file drag recorded for visual verification.")
        driver.app.terminate()
    }
}
