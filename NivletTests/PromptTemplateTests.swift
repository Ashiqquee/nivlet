import Testing
@testable import Nivlet

@Suite("Fill-in prompt rendering")
struct PromptTemplateTests {
    private let template = PromptTemplate(
        label: "Critique",
        segments: [.text("Review "), .field("page"), .text(" for "), .field("audience"), .text(". Keep "), .field("page"), .text(".")]
    )

    @Test("Repeated names produce one field in first-appearance order")
    func uniqueFields() {
        #expect(template.fieldNames == ["page", "audience"])
    }

    @Test("Incomplete fills cannot be copied")
    func incompleteBlocksCopy() {
        #expect(template.render([:]) == nil)
        #expect(template.render(["page": "Pricing"]) == nil)
        #expect(template.render(["page": "Pricing", "audience": "   \n"]) == nil)
        #expect(template.missingFields(in: ["page": "Pricing"]) == ["audience"])
    }

    @Test("Repeated fields share one value")
    func repeatedFieldsShareValue() {
        let text = template.render(["page": "Pricing", "audience": "designers"])
        #expect(text == "Review Pricing for designers. Keep Pricing.")
    }

    @Test("Values are inserted literally and never reparsed")
    func valuesStayLiteral() {
        let text = template.render(["page": "{{audience}}", "audience": "\\{\\{x\\}\\} 🙂"])
        #expect(text == "Review {{audience}} for \\{\\{x\\}\\} 🙂. Keep {{audience}}.")
    }

    @Test("Values keep their own whitespace and line breaks")
    func valuesKeepWhitespace() {
        let text = template.render(["page": " Home\npage ", "audience": "x"])
        #expect(text == "Review  Home\npage  for x. Keep  Home\npage .")
    }

    @Test("A template without fields renders as-is")
    func noFields() {
        let plain = PromptTemplate(label: "Plain", segments: [.text("Just text")])
        #expect(plain.fieldNames.isEmpty)
        #expect(plain.render([:]) == "Just text")
    }
}
