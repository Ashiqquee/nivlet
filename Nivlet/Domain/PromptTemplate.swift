/// A fill-in prompt as literal text and named fields.
///
/// Parsed once from opt-in `{{field_name}}` source; values stay literal.
nonisolated struct PromptTemplate: Equatable, Sendable {
    enum Segment: Equatable, Sendable {
        case text(String)
        case field(String)
    }

    enum PreviewSpan: Equatable, Sendable {
        case text(String), value(String), missing(String)
        var text: String {
            switch self { case .text(let text), .value(let text): text; case .missing(let name): "{{\(name)}}" }
        }
    }

    func preview(_ values: [String: String]) -> [PreviewSpan] {
        segments.map { segment in
            switch segment {
            case .text(let text): .text(text)
            case .field(let name): Self.isFilled(values[name]) ? .value(values[name]!) : .missing(name)
            }
        }
    }

    var label: String
    var segments: [Segment]

    /// Unique field names in first-appearance order. Repeated names share one value.
    var fieldNames: [String] {
        var seen = Set<String>()
        return segments.compactMap { segment in
            guard case .field(let name) = segment, seen.insert(name).inserted else { return nil }
            return name
        }
    }

    /// A field counts as filled when it holds any non-whitespace character.
    static func isFilled(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.allSatisfy(\.isWhitespace)
    }

    func missingFields(in values: [String: String]) -> [String] {
        fieldNames.filter { !Self.isFilled(values[$0]) }
    }

    /// Complete text for copying, or `nil` while any field is empty.
    /// Values are inserted literally and never parsed again.
    func render(_ values: [String: String]) -> String? {
        guard missingFields(in: values).isEmpty else { return nil }
        return preview(values).map(\.text).joined()
    }
}


extension PromptTemplate {
    nonisolated enum ParseError: Error, Equatable, CustomStringConvertible {
        case malformedToken(Int)

        var description: String {
            switch self {
            case .malformedToken(let position):
                "Check the braces near character \(position). Use {{field_name}} for a blank, or escape literal braces with a backslash."
            }
        }
    }

    /// Parse once. Substituted values are never parsed as template source.
    nonisolated static func parse(_ source: String, label: String = "") throws -> PromptTemplate {
        let characters = Array(source)
        var segments: [Segment] = []
        var literal = ""
        var i = 0
        func flush() {
            if !literal.isEmpty { segments.append(.text(literal)); literal = "" }
        }
        while i < characters.count {
            let character = characters[i]
            if character == "\\", i + 1 < characters.count,
               characters[i + 1] == "{" || characters[i + 1] == "}" {
                literal.append(characters[i + 1]); i += 2
            } else if character == "{" {
                let start = i
                guard i + 1 < characters.count, characters[i + 1] == "{" else {
                    throw ParseError.malformedToken(i + 1)
                }
                i += 2
                var name = ""
                while i < characters.count, characters[i] != "}" {
                    name.append(characters[i]); i += 1
                }
                guard i + 1 < characters.count, characters[i] == "}", characters[i + 1] == "}",
                      let first = name.first, first.isASCII, first.isLetter,
                      name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else {
                    throw ParseError.malformedToken(start + 1)
                }
                flush(); segments.append(.field(name)); i += 2
            } else if character == "}" {
                throw ParseError.malformedToken(i + 1)
            } else {
                literal.append(character); i += 1
            }
        }
        flush()
        return PromptTemplate(label: label, segments: segments)
    }
}
