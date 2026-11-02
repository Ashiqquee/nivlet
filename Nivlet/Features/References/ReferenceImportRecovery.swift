import SwiftUI

struct ReferenceImportRecovery: View {
    let kit: PocketLibrary
    let chooseAgain: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    private var pending: [ReferenceImportResult] {
        kit.importResults.filter {
            switch $0.state {
            case .failed, .needsConfirmation: true
            case .importing, .saved: false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Review files")
                    .shelfFont(.caption, weight: .semibold).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if !kit.failedImportIDs.isEmpty {
                    Button("Retry failed") { Task { await kit.retryImports(kit.failedImportIDs) } }
                        .buttonStyle(ShelfButtonStyle(compact: true)).disabled(kit.isImporting)
                        .fixedSize()
                }
                Button("Done") { kit.dismissImportResults(); dismiss() }
                    .disabled(kit.isImporting).keyboardShortcut(.defaultAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pending) { result in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: symbol(result)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).lineLimit(2).help(result.name)
                                Text(message(result)).foregroundStyle(ShelfStyle.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if result.state == .needsConfirmation {
                                Button("Import anyway") { Task { await kit.retryImports([result.id], confirmed: true) } }
                                    .buttonStyle(ShelfButtonStyle(compact: true)).disabled(kit.isImporting)
                                    .fixedSize()
                            } else if case .failed = result.state, result.referenceID == nil {
                                Button("Choose again…") { chooseAgain(result.id) }
                                    .buttonStyle(ShelfButtonStyle(compact: true)).disabled(kit.isImporting)
                                    .fixedSize()
                                    .accessibilityLabel("Choose \(result.name) again")
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: min(140, CGFloat(pending.count) * 64))
        }
        .shelfFont(.body).padding(18).frame(width: 340)
        .interactiveDismissDisabled(kit.isImporting)
        .onChange(of: kit.isImporting) {
            if !kit.isImporting, pending.isEmpty { dismiss() }
        }
    }

    private func symbol(_ result: ReferenceImportResult) -> String {
        "exclamationmark.triangle"
    }
    private func message(_ result: ReferenceImportResult) -> String {
        switch result.state {
        case .importing, .saved: ""
        case .needsConfirmation: "Over 500 MB. Import a copy? Files above 2 GB are refused."
        case .failed(let message): message
        }
    }
}
