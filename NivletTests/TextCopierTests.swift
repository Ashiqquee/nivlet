import AppKit
import Testing
@testable import Nivlet

@Suite("Explicit copy")
struct TextCopierTests {
    /// A private pasteboard keeps tests away from the person's clipboard.
    private func scratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("ashique.nivlet.tests.\(UUID().uuidString)"))
    }

    @Test(
        "Copies reviewed text byte for byte",
        arguments: [
            "Plain sentence.",
            "Emoji ✅ 👩🏽‍💻 and accents: café, naïve, Ελληνικά, 日本語",
            "Line one\nLine two\n\nLine four",
            "Windows endings\r\nstay as reviewed\r\n",
            "Old Mac\rending",
            "  leading and trailing whitespace  \n",
            "Token-like text {{field}} stays literal",
            String(repeating: "Long instruction text. ", count: 5_000),
        ]
    )
    func copiesExactly(text: String) throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }

        #expect(TextCopier.copy(text, to: pasteboard))
        let copied = try #require(pasteboard.string(forType: .string))
        #expect(Array(copied.utf8) == Array(text.utf8))
    }

    @Test("Copy replaces earlier pasteboard contents")
    func replacesPreviousContents() {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("old", forType: .string)
        pasteboard.setString("https://example.com", forType: .URL)

        TextCopier.copy("new", to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "new")
        #expect(pasteboard.string(forType: .URL) == nil)
    }
}
