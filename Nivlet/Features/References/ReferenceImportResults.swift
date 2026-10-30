import SwiftUI

struct ReferenceImportResults: View {
    let kit: PocketLibrary
    let chooseAgain: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Imports · \(kit.importResults.filter { $0.state == .saved }.count) of \(kit.importResults.count) saved")
                    .shelfFont(.caption, weight: .semibold).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if !kit.failedImportIDs.isEmpty {
                    Button("Retry failed") { Task { await kit.retryImports(kit.failedImportIDs) } }
                        .buttonStyle(ShelfButtonStyle(compact: true)).disabled(kit.isImporting)
                        .fixedSize()
                }
                Button { kit.dismissImportResults() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Dismiss import results").disabled(kit.isImporting)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(kit.importResults) { result in
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
            .frame(maxHeight: 140)
        }
        .shelfFont(.caption).padding(12).shelfWell(radius: 10)
        .padding(.horizontal, 14).padding(.bottom, 10)
    }

    private func symbol(_ result: ReferenceImportResult) -> String {
        switch result.state { case .saved: "checkmark.circle"; case .importing: "arrow.down.circle"; default: "exclamationmark.triangle" }
    }
    private func message(_ result: ReferenceImportResult) -> String {
        switch result.state {
        case .importing: "Importing…"
        case .saved: result.warning ? "Saved · over 100 MB; transfers may take longer." : "Saved"
        case .needsConfirmation: "Over 500 MB. Import a copy? Files above 2 GB are refused."
        case .failed(let message): message
        }
    }
}
