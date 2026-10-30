// Build with xcrun swiftc; run only against the isolated phase6review bundle.
// See docs/implementation/phase6-beta.md. Does not launch or inspect the working app.
import AppKit
import ApplicationServices

let bundleID = "ashique.nivlet.phase6review"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    fatalError("Launch the isolated Phase 6 review app first")
}
let root = AXUIElementCreateApplication(app.processIdentifier)
let board = NSPasteboard(name: .init("nivlet-verification-phase6"))
func value(_ e: AXUIElement, _ key: String) -> Any? {
    var result: CFTypeRef?; AXUIElementCopyAttributeValue(e, key as CFString, &result); return result
}
func descendants(_ e: AXUIElement) -> [AXUIElement] {
    [e] + (value(e, kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap(descendants)
}
func elements() -> [AXUIElement] {
    // Exclude the system menu bar, including the person's Recent Items.
    (value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []).flatMap(descendants)
}
func find(_ label: String, role: String? = nil) -> AXUIElement? {
    elements().first {
        (role == nil || value($0, kAXRoleAttribute) as? String == role) &&
        (value($0, kAXDescriptionAttribute) as? String == label || value($0, kAXTitleAttribute) as? String == label)
    }
}
func check(_ condition: Bool, _ label: String) {
    guard condition else { print("FAIL", label); exit(1) }
    print("PASS", label)
}
func wait(_ label: String, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(8)
    while !condition(), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    check(condition(), label)
}
func press(_ label: String) {
    wait("Find \(label)") { find(label) != nil }
    let result = AXUIElementPerformAction(find(label)!, kAXPressAction as CFString)
    check([AXError.success, .cannotComplete, .invalidUIElement].contains(result), "Press \(label)")
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
}
func text() -> String {
    elements().flatMap { e in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap { value(e, $0) as? String } }.joined(separator: "\n")
}
func activate() {
    app.activate()
    wait("Review app owns keyboard input") { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID }
}
func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
    activate()
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.flags = flags; event.post(tap: .cghidEventTap)
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
func type(_ text: String) {
    activate()
    for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        if index > 0 { key(36) }
        let chars = Array(line.utf16)
        if !chars.isEmpty {
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                event.post(tap: .cghidEventTap)
            }
        }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
}
func focused() -> AXUIElement? { value(root, kAXFocusedUIElementAttribute).map { $0 as! AXUIElement } }
func frame() -> (CGRect, CGWindowID)? {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    guard let window = windows.first(where: {
        ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier &&
        (($0[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) >= 300
    }), let b = window[kCGWindowBounds as String] as? [String: Double],
          let id = window[kCGWindowNumber as String] as? CGWindowID else { return nil }
    return (CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!), id)
}
func reopen() throws {
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [app.bundleURL!.path]; try process.run(); process.waitUntilExit()
}
let args = Array(CommandLine.arguments.dropFirst())
guard let stage = args.first else { fatalError("Use sample, keyboard, warm <json>, capture <png>, resize <width> <height>, settings <item>, inspect, or quit") }
if stage != "quit", frame() == nil { try reopen(); wait("Review panel open") { frame() != nil } }

switch stage {
case "sample":
    wait("Automatic first run") { text().contains("Your work,") }
    press("Try a sample pocket")
    wait("Sample pocket saved and selected") { find("Pocket: Sample pocket") != nil }
    check(find("Writing style") != nil && find("Explain a concept") != nil, "Both sample prompts exposed")
    if find("Pin panel") != nil { press("Pin panel") }
    press("Writing style"); press("Copy prompt")
    check(board.string(forType: .string) == "Write in plain, specific language. Keep my meaning and voice. Use concrete examples.", "Exact reviewed text copied privately")
    key(53)
    wait("Escape closes preview") { find("Writing style", role: "AXButton") != nil }
    press("Collapse")
    wait("First-run completion releases collapse guard") { frame() == nil }
    try reopen()
    wait("Saved sample remains available") { find("Writing style", role: "AXButton") != nil }
case "keyboard":
    // The pointer opener deliberately leaves the other app focused. Exercise
    // keyboard access through the same reopen path as Spotlight/Finder instead.
    wait("Review controls available") { find("Pin panel") != nil || find("Unpin panel") != nil }
    if find("Pin panel") != nil { press("Pin panel") }
    activate()
    wait("Panel available before keyboard reopen") { find("Collapse") != nil }
    press("Collapse")
    wait("Tucked before keyboard reopen") { frame() == nil }
    try reopen()
    wait("Keyboard reopen shows panel") { find("Collapse") != nil }
    key(18, .maskCommand) // Prompts
    key(3, .maskCommand) // Search
    wait("Command-F focuses search") { focused().flatMap { value($0, kAXDescriptionAttribute) as? String }?.hasPrefix("Search in") == true }
    key(0, .maskCommand); type("Explain")
    wait("Search results update") { text().contains("1 result") }
    key(53)
    wait("Escape clears query first") { find("Writing style", role: "AXButton") != nil }
    key(45, .maskCommand) // New
    wait("Command-N focuses title") { focused().flatMap { value($0, kAXDescriptionAttribute) as? String } == "Title" }
    type("Beta keyboard prompt")
    key(48) // Native Tab from title to the ordinary text view
    wait("Tab reaches prompt editor") { focused().flatMap { value($0, kAXDescriptionAttribute) as? String } == "Prompt text" }
    let expected = "Keep this exact text ✅ and {{literal}}.\nSecond line.  "
    type(expected)
    key(1, .maskCommand) // Save
    wait("Command-S saves prompt") { find("Beta keyboard prompt", role: "AXButton") != nil }
    key(3, .maskCommand); key(0, .maskCommand); type("Beta keyboard prompt")
    key(36)
    wait("Return opens selected result preview") { find("Copy prompt") != nil }
    key(36, .maskCommand)
    check(board.string(forType: .string) == expected, "Native editor, save, preview and copy retain exact Unicode and whitespace")
    key(53); key(20, .maskCommand) // Scratchpad
    key(45, .maskCommand)
    wait("Command-N focuses new to-do") { focused().flatMap { value($0, kAXDescriptionAttribute) as? String } == "New to-do" }
    type("Keyboard task ✅"); key(36)
    wait("Return creates accessible checkbox") { find("Keyboard task ✅", role: "AXCheckBox") != nil }
    key(53)
    wait("Escape tucks root") { frame() == nil }
    try reopen()
    wait("Tucking preserves scratchpad") { find("Keyboard task ✅", role: "AXCheckBox") != nil }
case "pin":
    if find("Pin panel") != nil { press("Pin panel") }
case "editor":
    key(18, .maskCommand); key(45, .maskCommand)
    wait("Editor opened") { find("Title", role: "AXTextField") != nil }
case "tool":
    precondition(args.count == 2)
    key(["prompts": CGKeyCode(18), "references": CGKeyCode(19), "notes": CGKeyCode(20)][args[1]]!, .maskCommand)
case "settings":
    precondition(args.count >= 2)
    press("Panel settings")
    for item in args.dropFirst() { press(item) }
case "resize":
    precondition(args.count == 3)
    let windows = value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
    guard let window = windows.first(where: { value($0, kAXDescriptionAttribute) as? String == "Nivlet panel" }) else { fatalError("No review panel") }
    var size = CGSize(width: Double(args[1])!, height: Double(args[2])!)
    check(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!) == .success, "Resize review panel")
case "capture":
    precondition(args.count == 2)
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    guard let (rect, id) = frame() else { fatalError("No review window") }
    let capture = Process(); capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", String(id), args[1]]
    try capture.run(); capture.waitUntilExit()
    check(capture.terminationStatus == 0, "Captured synthetic window \(rect)")
case "warm":
    precondition(args.count == 2)
    guard let (target, _) = frame() else { fatalError("Open the shelf first") }
    var samples: [Double] = []
    for _ in 0..<30 {
        _ = AXUIElementPerformAction(find("Collapse")!, kAXPressAction as CFString)
        wait("Tucked before timing") { find("Open Nivlet") != nil }
        let opener = find("Open Nivlet")!
        let start = ProcessInfo.processInfo.systemUptime
        _ = AXUIElementPerformAction(opener, kAXPressAction as CFString)
        var ready = false
        while ProcessInfo.processInfo.systemUptime - start < 3 {
            if let (rect, _) = frame(), abs(rect.minX - target.minX) < 1, abs(rect.minY - target.minY) < 1 { ready = true; break }
            Thread.sleep(forTimeInterval: 0.001)
        }
        check(ready, "Reached resting window geometry")
        samples.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    let ordered = samples.sorted()
    let report: [String: Any] = ["metric": "warm-open-resting-geometry", "unit": "ms", "n": samples.count,
        "p50": ordered[14], "p95": ordered[28], "max": ordered.last!, "samples": samples]
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: args[1]))
case "inspect":
    for e in elements() { print(value(e, kAXRoleAttribute) ?? "", value(e, kAXDescriptionAttribute) ?? "", value(e, kAXValueAttribute) ?? "") }
case "quit":
    check(app.terminate(), "Request normal quit")
    wait("Review app flushed and quit") { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }
default: fatalError("Unknown stage")
}
