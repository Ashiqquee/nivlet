import SwiftUI

/// A visual introduction. Detailed help and preferences stay one level away
/// from the two starting choices; both choices remain visible while resizing.
struct QuickStartView: View {
    let shell: ShellController
    @State private var addingSample = false
    @State private var error: String?
    @Environment(\.panelTextScale) private var textScale

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if let error {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Couldn’t save", systemImage: "exclamationmark.triangle")
                                    .shelfFont(.heading).accessibilityAddTraits(.isHeader)
                                Text(error).shelfFont(.body).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20).id("welcome-error")
                        } else if shell.introductionShowsGuide { guide }
                        else { welcome(availableHeight: geometry.size.height) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: shell.introductionShowsGuide || error != nil ? .top : .center)
                }
                .scrollIndicators(.visible)
                .onChange(of: error) {
                    if error != nil { proxy.scrollTo("welcome-error", anchor: .top) }
                }
                }
            }
            footer
        }
        .foregroundStyle(ShelfStyle.ink)
        .shelfFont(.body)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .panelSurface()
        .task { shell.focusArchivePreview() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if shell.introductionShowsGuide || error != nil {
                Button { shell.introductionShowsGuide = false; error = nil } label: {
                    Label("Welcome", systemImage: "chevron.left")
                }
                .buttonStyle(ShelfButtonStyle(compact: true))
            } else { Text("Nivlet").shelfFont(.title) }
            Spacer(minLength: 8)
            if !shell.introductionShowsGuide, error == nil {
                Button { shell.introductionShowsGuide = true } label: {
                    if textScale > 1.25 {
                        Image(systemName: "questionmark.circle").font(.system(size: 16)).frame(width: 24, height: 24)
                    } else {
                        Label("Quick guide", systemImage: "questionmark.circle")
                    }
                }
                .buttonStyle(ShelfButtonStyle(compact: true))
                .accessibilityLabel("Quick guide")
                .disabled(addingSample)
            }
            Menu { PanelSettings(shell: shell, includesHelp: false) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .fixedSize().accessibilityLabel("Welcome settings").help("Appearance, text size and screen edge")
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
    }

    private func welcome(availableHeight: CGFloat) -> some View {
        let showsScene = availableHeight > 300 && textScale < 1.5
        let compact = availableHeight < 300 || textScale >= 1.5
        return VStack(spacing: 0) {
            if showsScene {
                WelcomeShelfScene()
                    .frame(height: min(190, availableHeight * 0.44))
                    .padding(.bottom, 26)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 12) {
                Text(compact ? "Within reach." : "Your work,\nwithin reach.")
                    .shelfFont(compact ? .heading : .welcomeTitle).tracking(-0.7)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(compact ? "Keep prompts, files and next steps together." : "Keep prompts, references and next steps\nin one small space beside your work.")
                    .shelfFont(.body).lineSpacing(3)
                    .foregroundStyle(ShelfStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            if !compact { HStack(spacing: 7) {
                Image(systemName: "sidebar.right")
                Text("Open from the edge. Pin to stay.")
            }
            .shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.top, 22)
            }
        }
        .padding(.vertical, compact ? 12 : 24)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if shell.introductionShowsGuide {
                Button { shell.introductionShowsGuide = false } label: {
                    Text("Back to welcome").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            } else {
                Button(action: addSample) {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Text(addingSample ? "Adding sample…" : error == nil ? (textScale > 1.25 ? "Try sample" : "Try a sample pocket") : "Retry sample")
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        if addingSample { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)) }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                .disabled(addingSample || !shell.kit.isLoaded)
                .help("Adds two prompts and a checklist in a separate, removable pocket")
                Button(action: shell.finishIntroduction) {
                    Text(shell.kit.isBlankLibrary ? "Start blank" : "Back to pocket")
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(ShelfButtonStyle())
                    .disabled(addingSample)
            }
            if textScale <= 1.25 { privacy.padding(.top, 7) }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 20)
    }

    private var privacy: some View {
        Label("Local to your Mac. Yours to keep.", systemImage: "lock")
            .shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
            .multilineTextAlignment(.center)
    }

    private func addSample() {
        addingSample = true; error = nil
        Task {
            if !(await shell.addIntroductionSample()) {
                error = "Your sample is still here. Check disk space and write access, then retry."
                shell.panelModel.announceValidation(error!)
            }
            addingSample = false
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Three things to know")
                .shelfFont(.heading).accessibilityAddTraits(.isHeader)
            guideRow("Open when you need it", symbol: "sidebar.right",
                     detail: "Click the edge tab or open Nivlet from the menu bar. Click elsewhere to tuck it away.")
            guideRow("Keep a good prompt", symbol: "text.bubble",
                     detail: "Save text you reuse. Fill in any blanks, then copy the exact text you reviewed.")
            guideRow("Keep your place", symbol: "pin",
                     detail: "Pin keeps the panel open. Escape backs out of a preview, then tucks the panel.")
            DisclosureGroup("Keyboard shortcuts") {
                VStack(spacing: 12) {
                    shortcut("Prompts", keys: "⌘1")
                    shortcut("References", keys: "⌘2")
                    shortcut("Scratchpad", keys: "⌘3")
                    shortcut("Search", keys: "⌘F")
                    shortcut("New item", keys: "⌘N")
                    shortcut("Item actions", keys: "⌘K")
                }
                .padding(.top, 12)
            }
            .shelfFont(.body)
            Text("Paste or attach in your other app when you’re ready. Nivlet doesn’t read chats or send for you.")
                .shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guideRow(_ title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .foregroundStyle(ShelfStyle.secondary).frame(width: 24, height: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).shelfFont(.title)
                Text(detail).shelfFont(.body).foregroundStyle(ShelfStyle.secondary)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func shortcut(_ title: String, keys: String) -> some View {
        HStack { Text(title); Spacer(); Text(keys).monospaced() }
            .shelfFont(.body).foregroundStyle(ShelfStyle.secondary)
    }
}

/// Original native artwork showing the product's shelf/edge relationship.
/// This is an illustration, with no simulated interactive controls in AX.
private struct WelcomeShelfScene: View {
    @Environment(\.colorScheme) private var scheme
    private var card: Color { scheme == .dark ? Color(white: 0.14) : .white }
    private var outline: Color { scheme == .dark ? .white.opacity(0.12) : .black.opacity(0.09) }

    var body: some View {
        ZStack {
            Ellipse().fill(PanelTool.prompts.tint.opacity(0.13)).frame(width: 200, height: 80)
                .blur(radius: 35).offset(x: 40, y: 40)
            Ellipse().fill(PanelTool.references.tint.opacity(0.08)).frame(width: 120, height: 70)
                .blur(radius: 25).offset(x: -70, y: -20)
            HStack(spacing: 7) {
                VStack(spacing: 13) {
                    Image(systemName: "chevron.right").foregroundStyle(ShelfStyle.secondary)
                    smallTile("text.bubble.fill", color: PanelTool.prompts.tint)
                    Image(systemName: "photo.on.rectangle").foregroundStyle(ShelfStyle.secondary)
                    Image(systemName: "checklist").foregroundStyle(ShelfStyle.secondary)
                }
                .font(.system(size: 11, weight: .medium)).padding(8)
                .background(card, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(outline, lineWidth: 0.75))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("Prompts").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Label("My project", systemImage: "folder").font(.system(size: 9, weight: .medium))
                            .foregroundStyle(ShelfStyle.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("Find a little inspiration…")
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 10)).foregroundStyle(ShelfStyle.secondary)
                    .padding(8).background(ShelfStyle.keycap, in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            smallTile("text.bubble.fill", color: PanelTool.prompts.tint)
                            Text("Writing style").font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(ShelfStyle.favourite)
                        }
                        Text("Keep my meaning. Make it clearer.")
                            .font(.system(size: 10)).foregroundStyle(ShelfStyle.secondary)
                            .padding(.leading, 28)
                    }
                    .padding(9).background(ShelfStyle.keycap, in: RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 7) {
                        Image(systemName: "curlybraces").foregroundStyle(ShelfStyle.secondary).frame(width: 21)
                        Text("Explain a concept").font(.system(size: 11, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 9)
                }
                .padding(14).frame(width: 250)
                .background(card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(outline, lineWidth: 0.75))
                .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.1), radius: 20, y: 10)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc").foregroundStyle(ShelfStyle.secondary)
                    Text("Ready to copy").font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(card, in: Capsule())
                .overlay(Capsule().strokeBorder(outline, lineWidth: 0.75))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .offset(x: -12, y: 24)
            }
        }
        .foregroundStyle(ShelfStyle.ink)
    }

    private func smallTile(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(color)
            .frame(width: 21, height: 21)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Shared settings in the rail and the always-available menu-bar fallback.
struct PanelSettings: View {
    let shell: ShellController
    var includesHelp = true

    var body: some View {
        Picker("Appearance", selection: Binding(get: { shell.preferences.appearance }, set: shell.setAppearance)) {
            ForEach(PanelAppearance.allCases) { Text($0.title).tag($0) }
        }
        Picker("Text size", selection: Binding(get: { shell.preferences.textSize }, set: { shell.preferences.textSize = $0 })) {
            ForEach(PanelTextSize.allCases) { Text($0.title).tag($0) }
        }
        Picker("Screen edge", selection: Binding(get: { shell.preferences.edge }, set: shell.setEdge)) {
            ForEach(ScreenEdge.allCases) { Text($0.title).tag($0) }
        }
        Picker("Display", selection: Binding(get: { shell.preferences.displayID }, set: shell.setDisplay)) {
            let _ = shell.screensRevision
            Text("Primary display").tag(UInt32?.none)
            ForEach(NSScreen.screens, id: \.displayID) { Text($0.localizedName).tag($0.displayID) }
        }
        Toggle("Show edge tab", isOn: Binding(get: { shell.preferences.showsEdgeTab }, set: shell.setShowsEdgeTab))
        Toggle("Global shortcut \(GlobalHotKey.displayName)", isOn: Binding(get: { shell.preferences.shortcutEnabled }, set: shell.setShortcutEnabled))
        if let error = shell.shortcutError { Text(error) }
        Toggle("Full height", isOn: Binding(get: { shell.preferences.fullHeight }, set: shell.setFullHeight))
        Button("Reset panel size", action: shell.resetPanelSize)
        if includesHelp {
            Divider()
            Button("Quick start…", action: shell.showIntroduction)
        }
    }
}
