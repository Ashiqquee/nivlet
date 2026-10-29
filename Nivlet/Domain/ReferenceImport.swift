import Foundation

nonisolated struct ReferenceImportLimits: Sendable {
    var warningBytes: Int64 = 100_000_000
    var confirmationBytes: Int64 = 500_000_000
    var maximumBytes: Int64 = 2_000_000_000
    func warns(_ bytes: Int64) -> Bool { bytes > warningBytes }

    func validate(_ bytes: Int64, confirmed: Bool) throws {
        guard bytes <= maximumBytes else { throw LibraryStoreError.fileTooLarge }
        if bytes > confirmationBytes, !confirmed { throw LibraryStoreError.confirmLargeFile }
    }
}

nonisolated enum ReferenceImportSource: Sendable {
    case file(URL)
    case image(Data, name: String)
    case unavailable(name: String)

    var name: String {
        switch self { case .file(let url): url.lastPathComponent; case .image(_, let name), .unavailable(let name): name }
    }
}

nonisolated struct ReferenceImportResult: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        case importing, saved
        case failed(String), needsConfirmation
    }
    let id: UUID
    var name: String
    var state: State = .importing
    var referenceID: UUID?
    var warning = false
}
