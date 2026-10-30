import Foundation

/// Streaming, uncompressed archives. This actor performs no UI work and never
/// mutates SQLite. Validated restore bytes remain private until explicit commit.
actor PocketArchiveIO {
    let root: URL
    let limits: PocketArchiveLimits
    private var sessions: [UUID: PocketArchiveManifest] = [:]
    enum FailurePoint: Sendable { case exportBeforePublish, restoreAfterPlacement }
    private var failure: FailurePoint?
    init(root: URL, limits: PocketArchiveLimits = .init()) { self.root = root; self.limits = limits }
    func failNextForTesting(_ point: FailurePoint) { failure = point }
    private func stage(_ id: UUID) -> URL { root.appending(path: "archive-staging/\(id.uuidString)") }

    func prepareExport(id: UUID, pockets: [LibrarySnapshot]) throws -> ArchivePreview {
        var assets: [String: PocketArchiveManifest.Asset] = [:]
        let portable = try pockets.map { pocket in
            let references = try pocket.references.map { item in
                let digest = item.originalURL.deletingLastPathComponent().lastPathComponent
                guard ArchiveDisk.isDigest(digest), item.originalURL.standardizedFileURL == root.appending(path: "assets/\(digest)/original").standardizedFileURL
                    else { throw PocketArchiveError.corruptAsset }
                try ArchiveDisk.directory(root.appending(path: "assets"))
                try ArchiveDisk.directory(item.originalURL.deletingLastPathComponent())
                let (file, size) = try ArchiveDisk.reader(item.originalURL); try file.close()
                assets[digest] = .init(digest: digest, byteCount: size)
                return PocketArchiveManifest.Reference(id: item.id, label: item.label, note: item.note,
                    displayName: item.displayName, digest: digest, isFavorite: item.isFavorite)
            }
            return PocketArchiveManifest.Pocket(id: pocket.pocketID, name: pocket.pocketName, prompts: pocket.prompts,
                                               references: references, scratchpad: pocket.note)
        }
        let manifest = PocketArchiveManifest(pockets: portable, assets: assets.values.sorted { $0.digest < $1.digest })
        try manifest.validate(limits: limits)
        guard try JSONEncoder().encode(manifest).count <= limits.manifestBytes else { throw PocketArchiveError.limitExceeded }
        sessions[id] = manifest
        return ArchivePreview(id: id, manifest: manifest)
    }

    func export(id: UUID, to destination: URL) throws {
        guard let manifest = sessions[id] else { throw PocketArchiveError.expired }
        try ArchiveDisk.forbidInternal(destination, root: root)
        let access = destination.startAccessingSecurityScopedResource()
        defer { if access { destination.stopAccessingSecurityScopedResource() } }
        let parent = destination.deletingLastPathComponent()
        try ArchiveDisk.directory(parent)
        if FileManager.default.fileExists(atPath: destination.path) {
            let (existing, _) = try ArchiveDisk.reader(destination); try existing.close()
        }
        let metadata = try JSONEncoder().encode(manifest)
        try ArchiveDisk.checkSpace(at: parent, bytes: manifest.totalBytes + UInt64(metadata.count) + UInt64(manifest.assets.count * 160) + 16)
        // Foundation provides a writable, same-volume replacement directory for
        // a sandbox-selected file. A raw arbitrary sibling is outside the grant.
        let replacement = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                      appropriateFor: destination, create: true)
        let temporary = replacement.appending(path: "archive.partial")
        let writer = try ArchiveDisk.writer(temporary)
        defer { try? writer.close(); try? FileManager.default.removeItem(at: replacement) }
        try writer.write(contentsOf: ArchiveDisk.magic)
        try writer.write(contentsOf: ArchiveDisk.number(UInt64(metadata.count)))
        try writer.write(contentsOf: metadata)
        for asset in manifest.assets {
            try Task.checkCancellation()
            let path = Data(asset.archivePath.utf8)
            // Entry kind 0 = regular file. Other kinds are never emitted/accepted.
            try writer.write(contentsOf: Data([0]))
            try writer.write(contentsOf: ArchiveDisk.number(UInt64(path.count)))
            try writer.write(contentsOf: path)
            try writer.write(contentsOf: ArchiveDisk.number(asset.byteCount))
            let source = root.appending(path: asset.path)
            try ArchiveDisk.directory(source.deletingLastPathComponent())
            let (reader, size) = try ArchiveDisk.reader(source)
            defer { try? reader.close() }
            guard size == asset.byteCount else { throw PocketArchiveError.corruptAsset }
            try ArchiveDisk.copy(reader, count: size, to: writer, digest: asset.digest)
            guard (try reader.read(upToCount: 1))?.isEmpty != false else { throw PocketArchiveError.corruptAsset }
        }
        try Task.checkCancellation()
        try writer.synchronize(); try writer.close()
        if failure == .exportBeforePublish { failure = nil; throw LibraryStoreError.injectedFailure }
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
        // The selected-file grant need not allow opening its parent directory.
        // Publication has already completed; a denied directory fsync must not
        // report an intact, published archive as a failed export.
        try? ArchiveDisk.syncDirectory(parent)
    }

    func prepareRestore(id: UUID, from source: URL) throws -> ArchivePreview {
        try ArchiveDisk.forbidInternal(source, root: root)
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let (reader, archiveSize) = try ArchiveDisk.reader(source)
        defer { try? reader.close() }
        guard archiveSize <= limits.totalBytes + limits.manifestBytes + UInt64(limits.assets) * 160 + 16 else { throw PocketArchiveError.limitExceeded }
        guard try ArchiveDisk.exact(reader, 8) == ArchiveDisk.magic else { throw PocketArchiveError.invalid }
        let metadataSize = try ArchiveDisk.readNumber(reader)
        guard metadataSize <= limits.manifestBytes, metadataSize <= archiveSize else { throw PocketArchiveError.limitExceeded }
        let data = try ArchiveDisk.exact(reader, Int(metadataSize))
        let manifest: PocketArchiveManifest
        do { manifest = try JSONDecoder().decode(PocketArchiveManifest.self, from: data) }
        catch { throw PocketArchiveError.invalid }
        try manifest.validate(limits: limits)
        try ArchiveDisk.directory(root)
        try ArchiveDisk.checkSpace(at: root, bytes: manifest.totalBytes + metadataSize)
        let stagingRoot = root.appending(path: "archive-staging")
        try ArchiveDisk.directory(stagingRoot)
        let staging = stage(id); try ArchiveDisk.directory(staging)
        var ready = false
        defer { if !ready { try? FileManager.default.removeItem(at: staging) } }
        for asset in manifest.assets {
            guard try ArchiveDisk.exact(reader, 1) == Data([0]) else { throw PocketArchiveError.invalid }
            let pathSize = try ArchiveDisk.readNumber(reader)
            guard pathSize <= 128 else { throw PocketArchiveError.invalid }
            let path = try ArchiveDisk.exact(reader, Int(pathSize))
            guard path == Data(asset.path.utf8), try ArchiveDisk.readNumber(reader) == asset.byteCount else { throw PocketArchiveError.invalid }
            // Never append the supplied path or display name to staging.
            let url = staging.appending(path: asset.digest)
            let writer = try ArchiveDisk.writer(url)
            defer { try? writer.close() }
            try ArchiveDisk.copy(reader, count: asset.byteCount, to: writer, digest: asset.digest)
            try writer.synchronize(); try writer.close()
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        }
        guard (try reader.read(upToCount: 1))?.isEmpty != false else { throw PocketArchiveError.invalid }
        try Task.checkCancellation()
        try ArchiveDisk.syncDirectory(staging)
        sessions[id] = manifest; ready = true
        return ArchivePreview(id: id, manifest: manifest)
    }

    func placeRestore(id: UUID) throws -> [LibrarySnapshot] {
        guard let manifest = sessions[id] else { throw PocketArchiveError.expired }
        let assetsRoot = root.appending(path: "assets"); try ArchiveDisk.directory(assetsRoot)
        try ArchiveDisk.directory(root.appending(path: "archive-staging")); try ArchiveDisk.directory(stage(id))
        for asset in manifest.assets {
            try Task.checkCancellation()
            let staged = stage(id).appending(path: asset.digest)
            let folder = assetsRoot.appending(path: asset.digest); try ArchiveDisk.directory(folder)
            let destination = folder.appending(path: "original")
            if FileManager.default.fileExists(atPath: destination.path) {
                try ArchiveDisk.verify(destination, asset: asset)
            } else {
                // Verify staged bytes again at commit; a preview cannot authorise
                // later tampered bytes. Move places the verified read-only inode.
                try ArchiveDisk.verify(staged, asset: asset)
                try FileManager.default.moveItem(at: staged, to: destination)
                try ArchiveDisk.syncDirectory(folder)
            }
        }
        try ArchiveDisk.syncDirectory(assetsRoot)
        if failure == .restoreAfterPlacement { failure = nil; throw LibraryStoreError.injectedFailure }
        return manifest.newPockets(root: root)
    }

    func discard(_ id: UUID) throws {
        sessions[id] = nil
        let folder = stage(id)
        if FileManager.default.fileExists(atPath: folder.path) {
            try ArchiveDisk.directory(root.appending(path: "archive-staging")); try ArchiveDisk.directory(folder)
            try FileManager.default.removeItem(at: folder)
        }
    }
}
