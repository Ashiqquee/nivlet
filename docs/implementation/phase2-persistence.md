# Phase 2 — durable text tools

28 October 2026 · [Deliverables](../phases/phase2_deliverables.md) · [Architecture](../architecture.md)

Phase 2's local persistence gate passes on the development Mac. This does not close the outstanding Phase 1 display/Spaces and external file-handoff checks or establish macOS 14/27 runtime support.

## Storage and recovery

`LibraryStore` owns SQLite on its serial actor executor, away from the main actor. Schema **4** retains the pocket-owned `pockets`, `text_items`, `scratchpads` and `reference_items` tables and adds one `pending_save` row containing a Codable library snapshot. There are no new dependencies. An empty library creates its initial pocket durably on load; independent libraries receive different pocket IDs.

Before changing committed content, a separate SQLite transaction records the pending snapshot. The library replacement and removal of that pending row then commit together under `PRAGMA synchronous = FULL` and foreign-key enforcement. A failed or interrupted replacement rolls back to the last good content and retains the pending snapshot. This intentionally costs two commits per save. A failure before the intent itself commits cannot guarantee crash recovery; the interface retains the edits, shows a persistent error and prevents ordinary quit until saving succeeds. This is local recovery, not an export or backup format.

On relaunch, a pending snapshot is presented as unsaved content with **“Recovered unsaved changes. Review them, then retry saving.”** and a persistent **Retry** action. Focus, tool changes and tuck do not accept recovered changes automatically. Retry explicitly enables committing the reviewed pending library. A malformed recovery record or pocket mismatch blocks loading rather than replacing saved content. This build also refuses a database containing multiple pockets instead of flattening it.

Versions 1–3 receive a consistent SQLite backup through `sqlite3_backup` before migration. The existing instructions-to-prompts migration remains intact. A newer schema is rejected unchanged. Application support holds the database and snapshots; no working content or paths are logged or transmitted.

## Save and editing boundaries

- Scratchpad text and checkbox changes debounce for **300 ms**, below the 500 ms limit. The displayed source remains authoritative; notes and prompts stay separate.
- Save explicitly submits a validated prompt, including edits/rename. A failed submitted save remains in the pending library with Retry. Further unsubmitted editor changes still require Save or explicit discard. Editing is disabled during submission, and an old completion cannot close a different editor.
- Focus leaving the native scratchpad editor, tool changes, panel tuck and ordinary quit flush pending edits. Ordinary quit waits for a commit and stays open on failure. An unsubmitted editor draft requires keeping the editor open or explicitly discarding it.
- Favourite state, duplication and order persist. Duplicate uses an independent ID and preserves source, blank mode and favourite state. **Move up/down** in the existing action panel/context menu operate within the visible favourite or other-prompts group. Disabled boundary actions stay unavailable; named accessibility actions expose enabled commands.
- Deletions support repeated in-session Undo through the existing footer/keyboard route, restoring individual records and order without reverting newer notes or unrelated edits. Undo history does not survive restart; recoverable trash remains Phase 4 work.
- Revisions reject stale writes even after a newer failure. Saved appears only after the relevant successful commit. A failed or rejected write cannot report Saved.

## Exact-copy decision

**Preserve the reviewed string unchanged.** CRLF, CR and LF remain as reviewed, including mixtures. Do not trim whitespace, normalise Unicode, replace braces or append anything. `TextCopier.prepared` is the shared platform boundary. Native editor substitutions remain disabled. The copy confirmation remains “Copied to clipboard”.

## Verification

Environment: Apple M3 MacBook Air, arm64, macOS **26.6.2 (25G83)**, Xcode **27.1 (27A9275)**, macOS 27 SDK, Swift 6.4 / language mode 6, MainActor default isolation, Approachable Concurrency enabled. The macOS 14 deployment floor remains unchanged. No new runtime API above that floor was introduced.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData test
```

**56 tests, 91 cases including parameterized runs; 0 failed, 0 skipped, no runtime warnings.** Result: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.28_20-00-37-+0530.xcresult`. Build and tests passed outside the execution sandbox because its nested sandbox prevented Swift's macro plugin from launching. No Swift compiler warnings; Xcode's existing no-App-Intents metadata notice remains.

Coverage includes exact storage/clipboard bytes with emoji, composed/decomposed Unicode, long text, NUL, literal braces, blank lines, trailing spaces and mixed line endings; empty-prompt rejection; initial-pocket durability; v1/v2/v3 migration and pre-migration backups; rename/favourite/duplicate/reorder and repeated deletion Undo; autosave, immediate flush, overlapping saves and stale revisions; rollback and recovery across a fresh store/model.

`failNextCommitForTesting` injects rollback, real **SQLITE_FULL** via a connection-local `max_page_count` cap, or SQLite interruption via a progress handler. The disk-full test verifies that exact error, preserves last-good text and retries the pending snapshot after reopening. No test fills the developer's disk or uses the general clipboard; copy tests use private named pasteboards.

Native checks use a separately built **`ashique.nivlet.phase2review`** bundle and an isolated verification library containing only test text. The working app/library was not used. Native accessibility actions and key events targeted only that process.

| Check | Observed result |
|---|---|
| Prompt creation | Native title/body entry and Save produced the saved plain prompt, including literal braces and whitespace. |
| Immediate ordinary quit | After editing scratchpad text, requested termination immediately after the native text value updated. The process finished; prompt and latest scratchpad text survived relaunch. |
| Focus away/reopen | Edited scratchpad, activated Finder, reopened the edge tab and confirmed the exact current text. |
| Process interruption | A separate SQLite writer committed pending intent, began replacement, deleted prompt rows/changed the note and exited with `os._exit(23)` before commit. Reopening preserved the original prompt/note, retained pending intent and returned `integrity_check = ok`. |
| Native recovery | Relaunched after interruption; recovered prompt was reviewable and the unsaved message/Retry remained visible across focus changes. Explicit Retry cleared the warning and committed the recovered content. [Native capture](phase2-persistence/recovered-prompt-dark.png). |
| Prompt actions | Invoked Move down, Duplicate, Delete and Undo delete through the actual action menu. Reorder remained available after Undo. The menu also accepts the narrower shelf width at [320 × 360](phase2-persistence/actions-320x360-dark.png). |

[Native check output](phase2-persistence/native-checks.txt) records the process checks. The new evidence files are explicitly retained in `.gitignore`; existing local implementation notes remain ignored.

During native verification, focus initially caused an automatic retry that hid the recovery warning. The `needsRecoveryReview` gate fixes that; its regression test confirms routine flush cannot commit recovered edits and explicit Retry can.

## Limits carried forward

No physical power-loss test, whole-volume disk exhaustion or process kill inside the app's own SQLite call was performed. The interruption evidence combines an abruptly exited SQLite writer, injected interruption in the actual store and native recovery on relaunch. Unsaved edits inside the debounce interval can be lost on forced termination; ordinary lifecycle boundaries flush them. Unsubmitted prompt editor text is retained across tuck and protected on ordinary quit, but is not crash-journaled before Save.

External-app paste, full VoiceOver/Full Keyboard Access walks, enlarged text, alternate displays/Spaces and macOS 14/27 runtime behavior remain unverified here. There is one visible pocket; templates and reference imports pulled forward earlier remain unchanged by this phase. Archive/restore, multiple pockets and durable trash remain later work.
