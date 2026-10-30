import SwiftUI

struct PocketSearchView: View {
    let kit: PocketLibrary
    let model: PanelModel

    var body: some View {
        let results = kit.search(model.query, scope: model.searchScope)
        if results.isEmpty {
            ShelfEmptyState(symbol: "magnifyingglass", title: "No matches for “\(model.query)”",
                detail: model.searchScope == .active ? "Try another word or search All pockets." : "Search checks prompt text, labels and reference notes.",
                actionTitle: "Clear search") { model.query = "" }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        Text(results.count == 1 ? "1 result · \(model.searchScope.rawValue)" : "\(results.count) results · \(model.searchScope.rawValue)")
                            .shelfFont(.caption).foregroundStyle(ShelfStyle.secondary).padding(8)
                        ForEach(results) { result in
                            Button { Task { await model.openSearchResult(result, kit: kit) } } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: result.tool.symbol).frame(width: 18)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.label).shelfFont(.title).lineLimit(2)
                                        Text("\(result.pocketName) · \(result.tool.title)")
                                            .shelfFont(.caption).foregroundStyle(ShelfStyle.secondary)
                                        if !result.excerpt.isEmpty {
                                            Text(result.excerpt).shelfFont(.body).foregroundStyle(ShelfStyle.secondary).lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(model.selection == result.id ? ShelfStyle.selection : .clear,
                                            in: RoundedRectangle(cornerRadius: ShelfStyle.rowRadius))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).shelfPointer().id(result.id)
                            .accessibilityLabel("\(result.label), \(result.tool.title), pocket \(result.pocketName)")
                            .accessibilityValue(String(result.excerpt.prefix(180)))
                            .onHover { if $0 { model.selection = result.id } }
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
                .onChange(of: model.revealRequest) { if let id = model.revealRequest { proxy.scrollTo(id) } }
            }
        }
    }
}

struct MoveToPocketView: View {
    let kit: PocketLibrary
    let model: PanelModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move to pocket").shelfFont(.title)
            Text("The item will leave \(kit.pocketName). Its label, note and original file stay together.")
                .shelfFont(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(kit.pockets.filter { $0.pocketID != kit.pocketID }) { pocket in
                        Button { model.finishMove(to: pocket.pocketID, kit: kit) } label: {
                            Label(pocket.pocketName, systemImage: "folder").frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel("Move to \(pocket.pocketName)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { model.moveRequest = nil }.keyboardShortcut(.cancelAction)
        }
        .padding(20).frame(width: 250, height: 240)
    }
}
