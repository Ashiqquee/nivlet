# Phase 5 — portable ownership and recovery

30 October 2026 · **Local gate passed** · [Deliverables](../phases/phase5_deliverables.md) · [Archive format](../archive-format.md)

## Portable content and native flow

One/all live pockets export to an uncompressed `.nivlet` file containing a versioned UTF-8 JSON manifest and unchanged original bytes. The manifest preserves prompt/blank settings, favourite flags, order, independent reference labels/notes/original names, scratchpads and checklist text. Trash, unsubmitted/filled drafts, device navigation/settings, paid entitlement, credentials and derived files are deliberately excluded. Archive format 1 is independent of SQLite schema 5.

The pocket menu offers Export this pocket, Export all pockets, Restore archive and Clean unused files. The in-panel preview uses the existing compact shelf and `ShelfStyle` surface; `references/ui-ux/refbox/05-hero-demo-06s.png` informed the content/preview relationship. Pockets expand to reviewed prompt/source, reference/name/note and scratchpad summaries. Export's privacy notice remains visible outside the scrolling details. Native Save/Open panels choose only explicit files/destinations. User-selected sandbox access is now **read/write**, required for Save; reference imports still open sources `O_RDONLY` and never change the originals. No broad disk, Accessibility or recording permission is required to use the feature.

The shell protects the archive preview and independent file browser during activation/click-away. Background list/paste/create commands are blocked while the preview owns focus. Cancel cancels/awaits work and releases the session. The app stays open if Quit is requested during an active archive operation. Closing a ready preview or cancelling a file browser does not publish a restore. Working tools have no account/network dependency.

## Bounded validation and commit

`PocketArchiveIO` serialises heavy work off the main actor. A frozen export metadata revision pins every referenced digest before asynchronous work. Writer output is a new file in a Foundation-managed same-volume replacement directory; all originals are streamed/hashed, the file is synchronised, and an atomic rename publishes it. Failure before publication retains an existing destination. A later metadata edit cannot change an already reviewed export snapshot.

Restore opens a regular, non-symlink local file, checks the header/manifest and strict bounds, then writes only app-generated UUID staging folders and digest filenames. Archive paths and display names never control extraction paths. It rejects unsupported versions, malformed/duplicate IDs or paths, invalid blank syntax, missing/unreferenced assets, nonregular entry kinds, traversal/absolute/NUL/invalid path frames, tampered bytes, truncation, trailing data and size/count overflow. ZIP/TAR/compressed containers are not supported, so no decompression or archive expansion occurs. See [exact limits and framing](../archive-format.md).

All assets are verified before preview. Commit rechecks staged/existing bytes, places immutable originals, then appends all restored pockets in one SQLite transaction with new independent IDs. Existing pockets and the active pocket are retained. A failed restore does **not** journal an unaccepted destination revision: committed content and the normal pending-save journal remain unchanged after failure/relaunch. Placed but unreferenced assets are recoverable orphans; they are pinned until cancellation/interruption reconciliation and remain age-gated thereafter. Cancellation is checked before commit; after durable commit, cancellation cannot turn success into an error or cause a hidden duplicate retry.

## Retention and cleanup

Durable archive operation records contain operation identity, owner PID and asset digests only. An export or validated restore pins its assets. Validation with an unknown digest set protects all assets. Startup reconciles operations whose owning process is gone; records belonging to a live process are kept. PID reuse conservatively keeps a pin. Unreadable/unknown retention records pause cleanup and show a persistent review notice; the working library still opens.

Imports awaiting their first metadata commit have in-memory digest pins, including reused old orphans. Cleanup also checks the committed live/trash graph, the pending-save graph, in-session item Undo and every migration snapshot's live/pending references. A snapshot keeps originals needed for rollback even if the current library no longer references them.

Cleanup is explicit from the menu. It first saves removal of expired (seven-day) trash metadata, then removes only unowned digest assets older than 24 hours. Interrupted reference staging is removed only for recognised old UUID folders containing regular staged originals. Unknown folders and symlink directories are not traversed. A failed metadata save prevents file cleanup. Live shared-digest owners, recoverable trash, Undo, pending saves, imports and active exports retain their originals. Transfer-export files are independent byte copies and keep the existing 24-hour handoff retention; this cleanup never deletes them or a user's exported `.nivlet` archive. Migration backups are not automatically pruned.

## Migration rollback and recovery procedure

All schema 1–4 upgrade steps now share one SQLite transaction after a consistent SQLite backup. An interrupted/injected migration rolls back the **entire** upgrade. Snapshots are written under `snapshots/library-v<version>-<UUID>.sqlite`. No schema bump was needed for Phase 5. The snapshot is database metadata plus journal content; original assets remain in the library's `assets` directory and cleanup retains their references.

For the current development build:

1. Quit Nivlet. Preserve the complete affected application-support folder by duplicating it to a separate location; include `library.sqlite`, any `-wal`/`-shm` files, `assets`, `snapshots`, staging and operation records. Never replace a running database or delete the only copy.
2. Work on a **disposable copy** first. Choose the pre-migration snapshot matching the intended schema/app version. Copy that snapshot into the disposable root as `library.sqlite`, alongside copies of the retained original assets. Do not mix the snapshot with later database sidecars; remove only stale `library.sqlite-wal`/`-shm` from the disposable copy, keeping the untouched full backup elsewhere.
3. A compatible Nivlet build can open the copied snapshot and migrate it again. The test suite exercises this procedure with schema 1, literal former-instruction braces, a checklist and preserved identities. Another test proves migrated snapshots keep original bytes after references leave the current library. Pending recovery records rebase validated digests into the copied root; a test moves the old root out of reach and retries the pending save using only the copied originals.
4. Confirm pocket/item counts, reviewed text/checklists and original digests in the copy. Export a portable archive from the recovered copy and restore as new into another disposable root before considering replacement of working data. If using an older binary, it must support the chosen snapshot schema; an older binary correctly refuses the newer database.
5. Keep both the full failed-state copy and migration snapshot until recovery is independently reviewed. This workflow does not silently roll back the working library or overwrite newer edits.

Default sandbox data is below `~/Library/Containers/<bundle-id>/Data/Library/Application Support/ashique.nivlet.Nivlet/`; non-sandbox builds use their normal application-support location. Debug verification data lives in `verification-<name>` beneath that root, selected with `-NivletVerificationLibrary <letters-digits-or-hyphens>`. The native Phase 5 checks use a separate review bundle and synthetic roots. Never copy a test fixture over the working library.

Normal failed saves retain Phase 2/4's last-good data and pending complete revision with explicit review/Retry. A failed archive restore retains the existing library and its prepared preview for retry/cancel. Missing/corrupt originals block export/restore success. If an operation record cannot be read, preserve a full data copy and review that record before removing anything; do not bypass the conservative cleanup stop. App errors contain fixed recovery categories rather than dumping pocket text or private paths into diagnostic logs.

## Verification

Environment: Apple M3 MacBook Air, arm64, macOS 26.6.2 (25G83), Xcode 27.1 (27A9275), macOS 27 SDK, Swift 6.4/language mode 6, MainActor default isolation, macOS 14 deployment floor. No new dependency. Builds/tests/native helpers run outside the execution sandbox for Xcode/macOS UI access, without changing the working library or general clipboard.

**113 tests / 200 cases passed, zero failures/skips, no runtime warnings or Swift compiler warnings.** All prior regressions run. Final result: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.30_11-53-30-+0530.xcresult`. The final isolated native build passed too. Xcode emitted only the existing no-AppIntents-dependency metadata notices.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData test
```

Coverage includes multi-pocket clean-install round trips and exact Unicode/CR/LF/NUL/checklist/asset bytes; one-pocket exclusions; repeated restore without merges; consistent export and pre-publication failure; rollback, real connection-scoped SQLITE_FULL and SQLite interruption during restore commit; interruption after asset placement/retry; cancellation/preview reconciliation; hostile manifests and frames; strict bounds/no-space preflight; source/destination/internal/symlink boundaries; staged corruption at commit; live/trash/shared/pending/Undo/import/export/snapshot retention; running-process pins; relocated pending-original recovery; corrupt-pin fail-closed behavior; expired trash; unknown/symlink staging; whole-migration rollback and recovery from the snapshot.

Native evidence uses only bundle **`ashique.nivlet.phase5review`**, its synthetic **`phase5-source`** and initially clean **`phase5-clean`**/**`phase5-proof`** verification roots, and **`nivlet-verification-phase5`**. The original source is a generated `/tmp` file, removed before restore. The general clipboard and working library were not used. Restored-item inspection was pinned to keep the utility open while exercising controls.

| Native check | Observed result |
|---|---|
| One/all export preview | The all-pocket preview named both synthetic kits; the one-pocket preview included only the active restored kit. Counts and the privacy notice were visible. |
| Native Save and Cancel | Save opened the system browser. Cancel retained the reviewed preview. Saving into the exact disposable folder completed through the scoped sandbox grant. |
| Export bytes | Independent manifest/framing/SHA-256 checks matched the intended prompts, checklist and unchanged CRLF/Unicode original bytes. |
| Restore Cancel | Validated the archive and cancelled before commit. The initial empty pocket remained. |
| Invalid archive | A tampered-original fixture showed a persistent error; Restore as new was disabled. No pockets from that attempt appeared. |
| Clean restore | Exactly two independent new pockets appended to the initial empty pocket; IDs, ordered text/flags, notes, checklist and original-file metadata/digests matched the archive. No partial pockets remained from Cancel/refusal. |
| Use restored content | The plain prompt's literal braces/Unicode copied exactly to the private pasteboard. The original preview remained correct after source removal. The scratchpad retained checked/unchecked rows. |
| Cleanup | Native Clean unused files retained the restored owned original. Automated cases additionally exercise every retained owner, stale staging and failed/cancelled operations. |
| Narrow/error UI | Actual 320 × 360 export and corrupt-archive previews remained readable with Cancel/Save or disabled Restore accessible. |
| Native relaunch | Restored active kit, tool/checklist and original bytes survive normal quit/relaunch; final observations are in the native check record. |

[Observed native checks](phase5-recovery/native-checks.txt) · [Export preview](phase5-recovery/export-preview-dark.png) · [320 × 360 export](phase5-recovery/export-320x360-dark.png) · [320 × 360 invalid archive](phase5-recovery/invalid-320x360-dark.png)

Native verification caught and corrected the export write entitlement and raw temporary-sibling access; the final implementation uses user-selected read/write access and Foundation's same-volume replacement directory. Earlier harness attempts attached to stale review processes or assumed a pocket's search scope; those are not counted as acceptance results. Temporary lifecycle tracing was removed. The interactive fixture acquired one trailing scratchpad character after the initial exact restore comparison; it was preserved. The final full-content comparison uses an untouched `phase5-proof` native restore after quit/relaunch. Evidence contains synthetic content only.

This satisfies the **local Phase 5 gate** and the exercised AC-06 recovery/AC-04 byte-integrity boundaries. It does not complete release compatibility or Phase 6. Full VoiceOver/Full Keyboard Access, all unpinned focus transitions, reduced-motion toggles, OS 14/27 runtime, Intel, large-library/maximum 2 GB/20 GB throughput, actual device power loss, interruption inside a live filesystem rename, displays/Spaces and external app drops remain unverified. Size/expiry/failure boundaries use bounded fixtures, clocks and deterministic injection plus connection-scoped SQLITE_FULL; the host disk was not filled. Parent-directory synchronisation after export publication is best-effort where the selected-file sandbox grant permits it. Network was not disabled on the host; exercised operations use local files without a server/account. Licensing and distribution remain later phases.
