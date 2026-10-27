import SwiftUI

enum ShelfStyle {
    // Neutral appearance-aware roles. The shelf recedes behind the user's content.
    static let canvas = adaptive(light: 0.985, dark: 0.075)
    static let chrome = adaptive(light: 0.95, dark: 0.105)
    static let card = adaptive(light: 0.955, dark: 0.135)
    static let hover = adaptive(light: 0.90, dark: 0.19)
    static let ink = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .labelColor).opacity(0.75)
    static let border = Color(nsColor: .separatorColor)
    // The system focus color includes transparency for native glow drawing.
    // A custom 2 pt outline needs its opaque variant to stay visible.
    static let focusRing = Color(nsColor: NSColor.keyboardFocusIndicatorColor.withAlphaComponent(1))
    static let body = Font.system(size: 13)
    static let radius: CGFloat = 14
    static let settle = Animation.spring(duration: 0.28, bounce: 0)
    static let feedback = Animation.easeOut(duration: 0.12)

    private static func adaptive(light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(white: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light, alpha: 1)
        })
    }
}

/// Focus remains a native button behavior; only hover and press are customized.
struct ShelfButtonStyle: ButtonStyle {
    var filled = false
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        ShelfButtonBody(configuration: configuration, filled: filled, compact: compact)
    }
}

private struct ShelfButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let filled: Bool
    let compact: Bool
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        configuration.label
            .font(ShelfStyle.body.weight(.medium))
            .foregroundStyle(enabled ? ShelfStyle.ink : ShelfStyle.secondary)
            .padding(.horizontal, compact ? 6 : 11)
            .padding(.vertical, compact ? 5 : 7)
            .background(filled || hovered ? (hovered ? ShelfStyle.hover : ShelfStyle.card) : .clear,
                        in: RoundedRectangle(cornerRadius: compact ? 8 : 10))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: compact ? 8 : 10).strokeBorder(ShelfStyle.ink, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: configuration.isPressed)
            .onHover { hovered = enabled && $0 }
            .shelfPointer(enabled ? .pointingHand : .arrow)
    }
}

struct ShelfCardStyle: ViewModifier {
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.displayScale) private var scale
    func body(content: Content) -> some View {
        content
            .background(hovered ? ShelfStyle.hover : ShelfStyle.card, in: RoundedRectangle(cornerRadius: ShelfStyle.radius))
            .overlay {
                RoundedRectangle(cornerRadius: ShelfStyle.radius)
                    .strokeBorder(contrast == .increased ? ShelfStyle.ink : ShelfStyle.border.opacity(hovered ? 0.65 : 0.25),
                                  lineWidth: contrast == .increased ? 1 : 1 / scale)
                    .allowsHitTesting(false)
            }
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
    }
}

extension View { func shelfCard() -> some View { modifier(ShelfCardStyle()) } }

struct ShelfSection<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder var content: Content
    @State private var expanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : ShelfStyle.settle) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text(title).font(ShelfStyle.body.weight(.medium))
                    Spacer(minLength: 0)
                    Text(count, format: .number).font(ShelfStyle.body).monospacedDigit()
                }
                .foregroundStyle(ShelfStyle.secondary)
                .padding(.horizontal, 4).padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .shelfPointer()
            .accessibilityLabel("\(expanded ? "Collapse" : "Expand") \(title), \(count) items")
            .accessibilityAddTraits(.isHeader)
            if expanded { content.transition(.opacity.combined(with: .offset(y: -4))) }
        }
    }
}

struct ShelfEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    let actionTitle: String
    var action: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(ShelfStyle.secondary)
                .frame(height: 40).accessibilityHidden(true)
            VStack(spacing: 7) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(ShelfStyle.body).foregroundStyle(ShelfStyle.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Button(actionTitle, action: action).buttonStyle(ShelfButtonStyle(filled: true))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
