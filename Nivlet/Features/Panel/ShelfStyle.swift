import AppKit
import SwiftUI

enum ShelfStyle {
    // Translucent, launcher-style surfaces: a native material tinted toward a
    // near-black (dark) or near-white (light) canvas so text keeps its contrast.
    // Light mode is not the dark recipe inverted: a near-white canvas with white,
    // hairline-bordered cards, so depth comes from brighter surfaces, not grey fills.
    static let canvasTint = adaptive(light: NSColor(red: 0.965, green: 0.965, blue: 0.972, alpha: 0.94),
                                     dark: NSColor(red: 0.055, green: 0.055, blue: 0.065, alpha: 0.84))
    static let raised = adaptive(light: NSColor(white: 1, alpha: 0.92), dark: NSColor(white: 1, alpha: 0.055))
    static let hover = adaptive(light: NSColor(white: 0, alpha: 0.04), dark: NSColor(white: 1, alpha: 0.065))
    static let selection = adaptive(light: NSColor(white: 1, alpha: 1), dark: NSColor(white: 1, alpha: 0.10))
    static let keycap = adaptive(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.11))
    /// Opaque elevated fill for the copy toast.
    static let toast = adaptive(light: NSColor(white: 1, alpha: 1), dark: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1))
    /// Hover on controls that already rest on `keycap`.
    static let strong = adaptive(light: NSColor(white: 0, alpha: 0.1), dark: NSColor(white: 1, alpha: 0.17))
    static let hairline = adaptive(light: NSColor(white: 0, alpha: 0.085), dark: NSColor(white: 1, alpha: 0.08))
    /// Soft drop shadow for light-mode cards; dark mode relies on fills instead.
    static let cardShadow = adaptive(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 0, alpha: 0))
    /// The 1 pt top-edge sheen that makes a dark surface read as a lit object.
    static let sheen = adaptive(light: NSColor(white: 1, alpha: 0.9), dark: NSColor(white: 1, alpha: 0.13))
    static let ink = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .labelColor).opacity(0.72)
    static let tertiary = Color(nsColor: .labelColor).opacity(0.66)
    static let border = Color(nsColor: .separatorColor)
    static let success = Color(red: 0.19, green: 0.78, blue: 0.45)
    static let favourite = Color(red: 1.0, green: 0.76, blue: 0.18)
    /// Inverted ink: the primary button reads like a key light (white in dark, black in light).
    static let primaryFill = Color(nsColor: .labelColor)
    static let primaryText = Color(nsColor: .windowBackgroundColor)
    // The system focus color includes transparency for native glow drawing.
    // A custom 2 pt outline needs its opaque variant to stay visible.
    static let focusRing = Color(nsColor: NSColor.keyboardFocusIndicatorColor.withAlphaComponent(1))


    static let radius: CGFloat = 18
    static let rowRadius: CGFloat = 10
    static let settle = Animation.spring(duration: 0.28, bounce: 0)
    static let feedback = Animation.easeOut(duration: 0.12)
    static let pop = Animation.spring(duration: 0.3, bounce: 0)

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

// MARK: Tool identity

extension PanelTool {
    /// Each tool owns one hue, used for its tile, glow and progress marks — never for body text.
    var tint: Color {
        switch self {
        case .prompts: Color(red: 1.0, green: 0.52, blue: 0.22)
        case .references: Color(red: 0.22, green: 0.62, blue: 1.0)
        case .notes: Color(red: 0.2, green: 0.78, blue: 0.47)
        }
    }
    var gradient: LinearGradient {
        let deep: Color = switch self {
        case .prompts: Color(red: 0.91, green: 0.3, blue: 0.1)
        case .references: Color(red: 0.08, green: 0.4, blue: 0.9)
        case .notes: Color(red: 0.06, green: 0.58, blue: 0.34)
        }
        return LinearGradient(colors: [tint, deep], startPoint: .top, endPoint: .bottom)
    }
}

/// The gradient app-icon-style square that names a tool or item kind.
struct ToolTile: View {
    let tool: PanelTool
    var symbol: String? = nil
    var size: CGFloat = 26
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(tool.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            }
            .overlay {
                Image(systemName: symbol ?? tool.symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0.5, y: 0.5)
            }
            .frame(width: size, height: size)
            .shadow(color: tool.tint.opacity(0.35), radius: size * 0.22, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

/// Row glyphs stay quiet; gradient tiles identify the active tool in the chrome.
struct ItemGlyph: View {
    let tool: PanelTool
    let symbol: String
    var size: CGFloat = 26
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(ShelfStyle.secondary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Keyboard hint chips, e.g. `Keycap("⌘", "K")`. Decorative; actions expose shortcuts natively.
struct Keycap: View {
    let keys: [String]
    var inverted = false
    init(_ keys: String..., inverted: Bool = false) { self.keys = keys; self.inverted = inverted }
    init(keys: [String], inverted: Bool = false) { self.keys = keys; self.inverted = inverted }
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(1).fixedSize()
                    .frame(minWidth: 17, minHeight: 17)
                    .padding(.horizontal, key.count > 1 ? 4 : 0)
                    .background(inverted ? AnyShapeStyle(ShelfStyle.primaryText.opacity(0.16)) : AnyShapeStyle(ShelfStyle.keycap),
                                in: RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            }
        }
        .foregroundStyle(inverted ? AnyShapeStyle(ShelfStyle.primaryText.opacity(0.8)) : AnyShapeStyle(ShelfStyle.secondary))
        .accessibilityHidden(true)
    }
}

// MARK: Surfaces

/// Behind-window blur. The system substitutes an opaque fill under Reduce Transparency.
struct PanelMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // The panel is usually not key; keep the material lit instead of the inactive grey.
        view.state = .active
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        // HUD reads as smoked glass in dark; in light it turns muddy grey, so light uses the whiter popover material.
        view.material = context.environment.colorScheme == .dark ? .hudWindow : .popover
    }
}

struct PanelSurface: ViewModifier {
    var radius: CGFloat = ShelfStyle.radius
    /// Side attached to the display edge. A docked surface is a plain rectangle,
    /// like a sidebar; `nil` floats with rounded corners.
    var dockedEdge: HorizontalEdge? = nil
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        let leading: CGFloat = dockedEdge == nil ? radius : 0
        let trailing: CGFloat = dockedEdge == nil ? radius : 0
        let shape = UnevenRoundedRectangle(cornerRadii: .init(topLeading: leading, bottomLeading: leading,
                                                              bottomTrailing: trailing, topTrailing: trailing), style: .continuous)
        content
            .background { ZStack { PanelMaterial(); ShelfStyle.canvasTint } }
            .clipShape(shape)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(ShelfStyle.ink, lineWidth: 1)
                } else {
                    shape.strokeBorder(LinearGradient(colors: [ShelfStyle.sheen, ShelfStyle.hairline, ShelfStyle.hairline],
                                                      startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
            }
    }
}

extension View {
    func panelSurface(radius: CGFloat = ShelfStyle.radius, dockedEdge: HorizontalEdge? = nil) -> some View {
        modifier(PanelSurface(radius: radius, dockedEdge: dockedEdge))
    }

    /// A quiet raised well for inputs and grouped content.
    func shelfWell(radius: CGFloat = 10, focused: Bool = false, tint: Color? = nil) -> some View {
        background(ShelfStyle.raised.shadow(.drop(color: ShelfStyle.cardShadow, radius: 2, y: 1)),
                   in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(focused ? (tint ?? ShelfStyle.focusRing) : ShelfStyle.hairline, lineWidth: focused ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
    }
}

// MARK: Buttons

/// Ghost button. Focus remains a native button behavior; only hover and press are customized.
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
    @Environment(\.isFocused) private var focused

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous)
        configuration.label
            .shelfFont(.body, weight: .medium)
            .foregroundStyle(enabled ? ShelfStyle.ink : ShelfStyle.tertiary)
            .padding(.horizontal, compact ? 7 : 11)
            .padding(.vertical, compact ? 5 : 7)
            .background(hovered ? ShelfStyle.keycap : filled ? ShelfStyle.raised : .clear, in: shape)
            .overlay {
                if focused { shape.strokeBorder(ShelfStyle.focusRing, lineWidth: 2).allowsHitTesting(false) }
                else if contrast == .increased { shape.strokeBorder(ShelfStyle.ink, lineWidth: 1).allowsHitTesting(false) }
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: configuration.isPressed)
            .onHover { hovered = enabled && $0 }
            .shelfPointer(enabled ? .pointingHand : .arrow)
    }
}

/// The one high-emphasis action on a surface: inverted ink, like a lit key.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { PrimaryButtonBody(configuration: configuration) }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .shelfFont(.body, weight: .semibold)
            .foregroundStyle(enabled ? ShelfStyle.primaryText : ShelfStyle.secondary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(enabled ? AnyShapeStyle(ShelfStyle.primaryFill.opacity(hovered ? 0.86 : 1)) : AnyShapeStyle(ShelfStyle.raised), in: shape)
            .overlay { shape.strokeBorder(focused ? ShelfStyle.focusRing : enabled ? .clear : ShelfStyle.hairline, lineWidth: focused ? 2 : 1).allowsHitTesting(false) }
            .contentShape(shape)
            .shadow(color: .black.opacity(enabled ? 0.18 : 0), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: hovered)
            .animation(reduceMotion ? nil : ShelfStyle.feedback, value: configuration.isPressed)
            .onHover { hovered = enabled && $0 }
            .shelfPointer(enabled ? .pointingHand : .arrow)
    }
}

// MARK: Sections and empty states

struct ShelfSection<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder var content: Content
    @State private var expanded = true
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(reduceMotion ? nil : ShelfStyle.settle) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(title).shelfFont(.eyebrow)
                    Text(count, format: .number).shelfFont(.caption).monospacedDigit()
                        .foregroundStyle(ShelfStyle.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 8.5, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                        .opacity(hovered ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(ShelfStyle.secondary)
                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
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
    var tool: PanelTool? = nil
    var showsNewShortcut = false
    var action: () -> Void
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                contents(compact: geometry.size.height < 300).frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
            }
        }
    }

    private func contents(compact: Bool) -> some View {
        VStack(spacing: 12) {
            if !compact {
                ZStack {
                    if let tool {
                        RoundedRectangle(cornerRadius: 12).fill(ShelfStyle.keycap)
                            .frame(width: 54, height: 44).rotationEffect(.degrees(-12)).offset(x: -8, y: -3)
                        RoundedRectangle(cornerRadius: 12).fill(ShelfStyle.raised)
                            .frame(width: 54, height: 44).rotationEffect(.degrees(9)).offset(x: 7, y: 2)
                        Image(systemName: symbol).font(.system(size: 22, weight: .medium))
                            .foregroundStyle(tool.tint).frame(width: 54, height: 54)
                    } else {
                        Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(ShelfStyle.secondary)
                            .frame(width: 52, height: 52).shelfWell(radius: 15)
                    }
                }
                .frame(height: 68).accessibilityHidden(true)
            }
            VStack(spacing: 7) {
                Text(title).shelfFont(.heading)
                Text(detail).shelfFont(.body).foregroundStyle(ShelfStyle.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 240)
            }
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(actionTitle)
                    if showsNewShortcut { Keycap("⌘", "N", inverted: true) }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}
