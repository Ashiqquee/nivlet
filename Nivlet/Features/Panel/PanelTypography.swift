import SwiftUI

/// macOS has no Dynamic Type setting. This device-local choice enlarges the
/// shelf's text without scaling its window, hit areas or original media.
enum PanelTextSize: String, CaseIterable, Identifiable {
    case standard, large, extraLarge, double
    var id: String { rawValue }
    var scale: CGFloat {
        switch self { case .standard: 1; case .large: 1.25; case .extraLarge: 1.5; case .double: 2 }
    }
    var title: String { "\(Int(scale * 100))%" }
}

extension EnvironmentValues {
    @Entry var panelTextScale: CGFloat = 1
}

enum ShelfTextStyle {
    case body, caption, title, heading, display, welcomeTitle, eyebrow
    var size: CGFloat {
        switch self {
        case .body, .caption, .eyebrow: 13
        case .title: 14
        case .heading: 17
        case .display: 19
        case .welcomeTitle: 26
        }
    }
    var weight: Font.Weight {
        switch self { case .body, .caption: .regular; case .eyebrow: .medium; default: .semibold }
    }
}

private struct ShelfFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    var design: Font.Design = .default
    @Environment(\.panelTextScale) private var scale
    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design))
    }
}

extension View {
    func shelfFont(_ style: ShelfTextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(ShelfFont(size: style.size, weight: weight ?? style.weight))
    }
    func shelfFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ShelfFont(size: max(13, size), weight: weight, design: design))
    }
}
