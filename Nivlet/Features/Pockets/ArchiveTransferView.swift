import SwiftUI

struct ArchivePresentation: Identifiable {
    enum Mode { case export(all: Bool), restore(URL), cleanup }
    let id = UUID()
    let mode: Mode
}

struct ArchiveTransferView: View {
    let presentation: ArchivePresentation
    let kit: PocketLibrary
    let shell: ShellController
    let onClose: () -> Void
    @State private var work: Task<Void, Never>?
    @State private var closing = false

    private var title: String {
        switch presentation.mode {
        case .export: "Export pockets"
        case .restore: "Restore archive"
        case .cleanup: "Clean unused files"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            if case .export = presentation.mode {
                Text("Can contain private prompts, notes and files. Review before sharing.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if kit.isArchiveBusy {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Working with original files…") }
                    }
                    if let preview = kit.archivePreview {
                        Text("\(count(preview.names.count, "pocket")) · \(count(preview.promptCount, "prompt")) · \(count(preview.referenceCount, "reference"))")
                            .font(.subheadline.weight(.semibold))
                        Text(ByteCountFormatter.string(fromByteCount: Int64(preview.manifest.totalBytes), countStyle: .file) + " of original files")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(preview.manifest.pockets, id: \.id) { pocket in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(pocket.prompts.prefix(50)) { prompt in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Label(prompt.label, systemImage: prompt.usesFields ? "curlybraces" : "text.bubble")
                                            Text(prompt.source).lineLimit(3).foregroundStyle(.secondary)
                                        }
                                    }
                                    ForEach(pocket.references.prefix(50), id: \.id) { reference in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Label(reference.label, systemImage: "doc")
                                            Text(reference.displayName).foregroundStyle(.secondary)
                                            if !reference.note.isEmpty { Text(reference.note).lineLimit(3).foregroundStyle(.secondary) }
                                        }
                                    }
                                    if pocket.prompts.count > 50 { Text("\(pocket.prompts.count - 50) more prompts in this pocket.").foregroundStyle(.secondary) }
                                    if pocket.references.count > 50 { Text("\(pocket.references.count - 50) more references in this pocket.").foregroundStyle(.secondary) }
                                    Text("Scratchpad").fontWeight(.semibold)
                                    Text(pocket.scratchpad.isEmpty ? "Empty scratchpad" : pocket.scratchpad).lineLimit(4).foregroundStyle(.secondary)
                                }
                                .font(.caption).textSelection(.enabled).padding(.top, 4)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pocket.name).font(.subheadline.weight(.semibold))
                                    Text("\(count(pocket.prompts.count, "prompt")) · \(count(pocket.references.count, "reference")) · scratchpad")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    switch presentation.mode {
                    case .export:
                        Text("Deleted pockets, unsaved drafts, filled values, licences and device settings are excluded.").foregroundStyle(.secondary)
                    case .restore:
                        Text("Restore creates independent new pockets. Existing pockets stay intact, even when names match.")
                        Text("Nivlet checks file integrity before offering Restore. Scripts and linked resources are never opened.").foregroundStyle(.secondary)
                    case .cleanup:
                        Text("Remove original files that have no remaining owner, plus old interrupted imports. Files less than 24 hours old are kept.")
                        Text("Live pockets, recoverable trash, Undo, migration backups and active exports retain their originals. Pockets past their seven-day recovery period are removed.").foregroundStyle(.secondary)
                    }
                    if let error = kit.archiveError {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                            .accessibilityLabel(error)
                    }
                    if let message = kit.archiveMessage { Label(message, systemImage: "checkmark.circle") }
                }
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                Button(kit.archiveMessage == nil ? "Cancel" : "Done", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction).disabled(closing)
                Spacer(minLength: 0)
                if kit.archiveMessage == nil {
                    switch presentation.mode {
                    case .export:
                        Button("Save archive…") {
                            shell.chooseArchiveDestination { url in
                                if let url { work = Task { await kit.writeArchive(to: url) } }
                            }
                        }
                        .disabled(kit.archivePreview == nil || kit.isArchiveBusy)
                    case .restore:
                        Button("Restore as new") { work = Task { await kit.restoreArchive() } }
                            .disabled(kit.archivePreview == nil || kit.isArchiveBusy)
                    case .cleanup:
                        Button("Clean unused files") { work = Task { await kit.cleanUnusedFiles() } }
                            .disabled(kit.isArchiveBusy)
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(20).frame(width: 270, height: 300)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .onAppear {
            shell.focusArchivePreview()
            work = Task {
                await kit.dismissArchive()
                switch presentation.mode {
                case .export(let all): await kit.prepareArchiveExport(all: all)
                case .restore(let url): await kit.prepareArchiveRestore(from: url)
                case .cleanup: break
                }
            }
        }
    }

    private func count(_ value: Int, _ noun: String) -> String { "\(value) \(noun)\(value == 1 ? "" : "s")" }

    private func close() {
        closing = true; work?.cancel()
        Task {
            await work?.value
            await kit.dismissArchive()
            onClose()
        }
    }
}
