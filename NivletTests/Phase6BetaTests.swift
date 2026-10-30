import AppKit
import Foundation
import Testing
@testable import Nivlet

@Suite("Phase 6 beta")
struct Phase6BetaTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "nivlet-phase6-\(UUID().uuidString)")
    }

    @Test("Introduction and text-size choices persist; the shortcut remains opt-in")
    func preferences() {
        let name = "nivlet-phase6-prefs-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let prefs = ShellPreferences(defaults: defaults)
        #expect(!prefs.hasCompletedIntroduction)
        #expect(!prefs.shortcutEnabled)
        #expect(prefs.textSize == .standard)
        prefs.hasCompletedIntroduction = true; prefs.textSize = .double
        let reopened = ShellPreferences(defaults: defaults)
        #expect(reopened.hasCompletedIntroduction)
        #expect(reopened.textSize.scale == 2)
        #expect(!reopened.shortcutEnabled)
    }

    @Test("Sample creation preserves existing work and survives relaunch and recoverable deletion")
    func sampleOwnership() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let kit = PocketLibrary(root: folder); await kit.load()
        #expect(kit.isBlankLibrary)
        let originalID = kit.pocketID
        #expect(await kit.savePrompt(id: nil, label: "My work", source: "Exact ✅ {{literal}}", favorite: false))
        kit.note = "[x] Keep me"; #expect(await kit.flush())
        let before = kit.collection
        #expect(!kit.isBlankLibrary)
        #expect(await kit.addQuickStartPocket())
        let sampleID = kit.pocketID
        #expect(sampleID != originalID)
        #expect(kit.pockets.first == before.pockets.first)
        #expect(kit.prompts.count == 2)
        let template = try #require(kit.prompts.first(where: \.usesFields)?.template)
        #expect(template.render(["topic": "Unicode ✅", "audience": "builders"]) == "Explain Unicode ✅ to builders. Start with an everyday example, then build up the details.")
        #expect(await kit.addQuickStartPocket())
        #expect(kit.pockets.count == 2) // repeat/retry cannot create duplicate samples
        let reopened = PocketLibrary(root: folder); await reopened.load()
        #expect(reopened.collection == kit.collection)
        #expect(await reopened.deletePocket())
        #expect(reopened.pockets.count == 1)
        #expect(reopened.prompts == before.pockets[0].prompts)
        #expect(reopened.restorePocket(id: sampleID))
        #expect(await reopened.flush())
        #expect(reopened.pockets.count == 2)
    }

    @Test("A failed sample commit retains one retry identity and a recoverable pending revision")
    func failedSample() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(root: folder)
        let failing = PocketLibrary(root: folder, store: store); await failing.load()
        await store.failNextCommitForTesting(.rollback)
        #expect(!(await failing.addQuickStartPocket()))
        let id = failing.pocketID
        #expect(failing.hasUnsavedChanges)
        #expect(failing.pockets.count == 2)
        let recovered = PocketLibrary(root: folder); await recovered.load()
        #expect(recovered.needsRecoveryReview)
        #expect(!recovered.isBlankLibrary)
        #expect(recovered.pocketID == id)
        #expect(await failing.addQuickStartPocket())
        #expect(failing.pocketID == id)
        #expect(failing.pockets.count == 2)
        let reopened = PocketLibrary(root: folder); await reopened.load()
        #expect(!reopened.needsRecoveryReview)
        #expect(reopened.collection == failing.collection)
    }

    @Test("Escape clears search before tucking and preserves unsubmitted editor text")
    func escapeLevels() {
        let shell = ShellController(kit: PocketLibrary(preview: true))
        shell.panelModel.query = "query"
        #expect(shell.handleEscape())
        #expect(shell.panelModel.query.isEmpty)
        shell.panelModel.beginNew()
        shell.panelModel.draft?.text = "Keep this draft ✅"
        shell.panelModel.draft?.hasChanges = true
        #expect(shell.handleEscape())
        #expect(shell.panelModel.showDiscardConfirmation)
        #expect(shell.panelModel.draft?.text == "Keep this draft ✅")
    }

    @Test("Escape leaves the quick guide before completing the introduction")
    func introductionGuideNavigation() {
        let name = "nivlet-guide-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let shell = ShellController(preferences: ShellPreferences(defaults: defaults), kit: PocketLibrary(preview: true))
        shell.showIntroduction()
        shell.introductionShowsGuide = true
        #expect(shell.handleEscape())
        #expect(!shell.introductionShowsGuide)
        #expect(shell.showsIntroduction)
        #expect(!shell.preferences.hasCompletedIntroduction)
        #expect(shell.handleEscape())
        #expect(!shell.showsIntroduction)
        #expect(shell.preferences.hasCompletedIntroduction)
        shell.showIntroduction()
        #expect(!shell.introductionShowsGuide)
    }

    @Test("Completing or failing first-run sample creation always releases the shell's dismissal guard")
    func introductionLifecycle() async throws {
        let folder = root(); defer { try? FileManager.default.removeItem(at: folder) }
        let name = "nivlet-phase6-intro-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryStore(root: folder)
        let kit = PocketLibrary(root: folder, store: store); await kit.load()
        let shell = ShellController(preferences: ShellPreferences(defaults: defaults), kit: kit)
        shell.showIntroduction()
        await store.failNextCommitForTesting(.rollback)
        #expect(!(await shell.addIntroductionSample()))
        #expect(!shell.isPreparingIntroduction)
        #expect(shell.showsIntroduction)
        #expect(!shell.preferences.hasCompletedIntroduction)
        #expect(await shell.addIntroductionSample())
        #expect(!shell.isPreparingIntroduction)
        #expect(!shell.showsIntroduction)
        #expect(shell.preferences.hasCompletedIntroduction)
        #expect(kit.pockets.count == 2)
    }

}
