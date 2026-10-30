import Foundation

nonisolated enum PocketArchiveError: LocalizedError, Sendable {
    case invalid, unsupportedVersion, limitExceeded, corruptAsset, noSpace, busy, expired, unsafeLocation
    var errorDescription: String? {
        switch self {
        case .invalid: "This isn't a valid Nivlet archive. Choose another archive."
        case .unsupportedVersion: "This archive needs a newer version of Nivlet. Your library hasn't changed."
        case .limitExceeded: "This archive exceeds the supported size or item limits. Export smaller groups of pockets."
        case .corruptAsset: "An original file is missing or damaged. Your library hasn't changed."
        case .noSpace: "There isn't enough free space. Free some space and try again."
        case .busy: "Finish the current file operation or recovery before trying again."
        case .expired: "This preview is no longer available. Choose the archive again."
        case .unsafeLocation: "Choose an archive outside Nivlet’s internal library folders."
        }
    }
}

nonisolated struct PocketArchiveLimits: Sendable {
    var manifestBytes: UInt64 = 16 * 1024 * 1024
    var assetBytes: UInt64 = 2_000_000_000
    var totalBytes: UInt64 = 20_000_000_000
    var assets = 20_000
    var pockets = 2_000
    var items = 100_000
}

/// Portable working content only. No internal URLs, view bookmarks, trash,
/// filled/editor drafts, entitlement, credentials or device preferences.
nonisolated struct PocketArchiveManifest: Codable, Equatable, Sendable {
    var formatVersion = 1
    var pockets: [Pocket]
    var assets: [Asset]

    struct Pocket: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var prompts: [SavedPrompt]
        var references: [Reference]
        var scratchpad: String
    }
    struct Reference: Codable, Equatable, Sendable {
        var id: UUID
        var label: String
        var note: String
        var displayName: String
        var digest: String
        var isFavorite: Bool
    }
    struct Asset: Codable, Equatable, Sendable {
        var digest: String
        var byteCount: UInt64
        var path: String { "assets/\(digest)/original" }
        // A path is deliberately encoded and checked, even though extraction
        // always uses an app-generated digest name rather than this input.
        var archivePath: String
        init(digest: String, byteCount: UInt64) {
            self.digest = digest; self.byteCount = byteCount; archivePath = "assets/\(digest)/original"
        }
    }
    var totalBytes: UInt64 { assets.reduce(0) { $0 + $1.byteCount } }

    func validate(limits: PocketArchiveLimits) throws {
        guard formatVersion == 1 else { throw PocketArchiveError.unsupportedVersion }
        guard !pockets.isEmpty, pockets.count <= limits.pockets, assets.count <= limits.assets else { throw PocketArchiveError.limitExceeded }
        guard Set(pockets.map(\.id)).count == pockets.count,
              Set(assets.map(\.digest)).count == assets.count else { throw PocketArchiveError.invalid }
        var total: UInt64 = 0; var count = 0; var ids = Set<UUID>(); var used = Set<String>()
        for asset in assets {
            guard ArchiveDisk.isDigest(asset.digest), asset.archivePath == asset.path else { throw PocketArchiveError.invalid }
            guard asset.byteCount <= limits.assetBytes, total <= limits.totalBytes,
                  asset.byteCount <= limits.totalBytes - total else { throw PocketArchiveError.limitExceeded }
            total += asset.byteCount
        }
        let available = Set(assets.map(\.digest))
        for pocket in pockets {
            guard PromptTemplate.isFilled(pocket.name) else { throw PocketArchiveError.invalid }
            count += pocket.prompts.count + pocket.references.count
            guard count <= limits.items else { throw PocketArchiveError.limitExceeded }
            for prompt in pocket.prompts {
                guard ids.insert(prompt.id).inserted, PromptTemplate.isFilled(prompt.label), PromptTemplate.isFilled(prompt.source),
                      !prompt.usesFields || (try? PromptTemplate.parse(prompt.source)) != nil else { throw PocketArchiveError.invalid }
            }
            for reference in pocket.references {
                guard ids.insert(reference.id).inserted, PromptTemplate.isFilled(reference.label),
                      !reference.displayName.isEmpty, !reference.displayName.contains("\0"), available.contains(reference.digest)
                      else { throw PocketArchiveError.invalid }
                used.insert(reference.digest)
            }
        }
        guard used == available else { throw PocketArchiveError.invalid }
    }

    func newPockets(root: URL) -> [LibrarySnapshot] {
        let sizes = Dictionary(uniqueKeysWithValues: assets.map { ($0.digest, Int64($0.byteCount)) })
        return pockets.map { pocket in
            LibrarySnapshot(pocketID: UUID(), pocketName: pocket.name,
                prompts: pocket.prompts.map { SavedPrompt(label: $0.label, source: $0.source, isFavorite: $0.isFavorite, usesFields: $0.usesFields) },
                references: pocket.references.map { reference in
                    let url = root.appending(path: "assets/\(reference.digest)/original")
                    return ReferenceItem(id: UUID(), label: reference.label, note: reference.note, displayName: reference.displayName,
                        originalURL: url, isImage: ReferenceAssetStore.isImageFile(url), byteCount: sizes[reference.digest], isFavorite: reference.isFavorite)
                }, note: pocket.scratchpad)
        }
    }
}

nonisolated struct ArchivePreview: Identifiable, Equatable, Sendable {
    let id: UUID
    let manifest: PocketArchiveManifest
    var names: [String] { manifest.pockets.map(\.name) }
    var promptCount: Int { manifest.pockets.reduce(0) { $0 + $1.prompts.count } }
    var referenceCount: Int { manifest.pockets.reduce(0) { $0 + $1.references.count } }
}

nonisolated struct AssetCleanupResult: Sendable, Equatable {
    var removedAssets = 0
    var removedStagingFolders = 0
    var reclaimedBytes: UInt64 = 0
}
