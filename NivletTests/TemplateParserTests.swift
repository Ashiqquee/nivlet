import Testing
@testable import Nivlet

@Suite("Saved prompt source grammar")
struct TemplateParserTests {
    @Test("Plain saved prompts need no fields and keep exact whitespace")
    func plainPrompt() throws {
        let source = "  My own prompt ✅\n\nKeep this spacing.\r\n"
        let parsed = try PromptTemplate.parse(source)
        #expect(parsed.fieldNames.isEmpty)
        #expect(parsed.render([:]) == source)
    }

    @Test("Ordinary saved prompts preserve braces without entering template mode")
    func plainSourceIsLiteral() {
        let source = #"Return { "answer": "{{literal}}" } exactly."#
        let prompt = SavedPrompt(label: "My JSON prompt", source: source)
        #expect(prompt.template?.fieldNames.isEmpty == true)
        #expect(prompt.template?.render([:]) == source)
        let fill = SavedPrompt(label: "Optional blanks", source: "Explain {{topic}}", usesFields: true)
        #expect(fill.template?.fieldNames == ["topic"])
    }

    @Test("Repeated names share one input, preserving first occurrence order")
    func repeatedFields() throws {
        let parsed = try PromptTemplate.parse("{{topic}} for {{audience_2}}; {{topic}} again")
        #expect(parsed.fieldNames == ["topic", "audience_2"])
        #expect(parsed.render(["topic": "{{literal}}", "audience_2": "you"]) == "{{literal}} for you; {{literal}} again")
    }

    @Test("Escaped literal braces do not become fields")
    func escapedBraces() throws {
        let parsed = try PromptTemplate.parse(#"Show \{\{literal\}\} and {{topic}}. C:\files"#)
        #expect(parsed.fieldNames == ["topic"])
        #expect(parsed.render(["topic": "x"]) == #"Show {{literal}} and x. C:\files"#)
    }

    @Test("Malformed fields cannot be saved", arguments: ["{{}}", "{{1topic}}", "{{topic name}}", "{{topic", "topic}}", "{{a{{b}}", "{a}", "{{a-b}}", "{{a}}}"])
    func malformed(_ source: String) {
        #expect(throws: PromptTemplate.ParseError.self) { try PromptTemplate.parse(source) }
    }
}
