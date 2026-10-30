# Phase 4 — project pockets, search and organisation

29 October 2026 · **Local gate passed** · [Deliverables](../phases/phase4_deliverables.md)

## Ownership and persistence

SQLite schema **5** stores ordered live and deleted pockets, explicit item ownership, reference favourites/byte counts and device-local navigation bookmarks. Schema 1–4 upgrades use the existing SQLite backup mechanism before migration. Existing pocket/item identities, reviewed text, scratchpads, original filenames and legacy pending-save intent survive. Newer schemas are refused unchanged.

`PocketCollection` is the complete metadata revision. Every pocket owns its prompts, references and one scratchpad. Global IDs are checked for uniqueness before a write or recovery is accepted. A complete revision is durably journalled before replacing committed metadata; the replacement, active-pocket selection and clearing of the journal share one transaction. A legacy one-pocket writer refuses to flatten a multi-pocket or trashed library.

Switching flushes first. A failed save or unreviewed recovery keeps the current pocket visible with Retry. Imports hold their originating pocket until the batch completes; switching is disabled during intake. After changing the active pocket, a failed selection commit retains the complete pending revision and persistent failure UI. It never reports Saved for the failed revision.

A duplicate receives new pocket/item IDs and independent labels, notes, favourite/order metadata and scratchpad text. Original bytes may share a digest. An explicit move changes the item's owner and keeps its identity/metadata; moving a template through the UI clears its filled values so the destination inherits no filled draft. No live cross-pocket links exist. A pocket change never changes an AI conversation.

## Drafts and navigation

Each pocket retains its in-session tool, inspector/editor, unsubmitted prompt draft, query, scope and selection. Filled values are keyed by globally unique template identity and remain separate from saved source. Switching returns to the same unsubmitted editor; source is not silently submitted. Quit checks drafts in every pocket, including inactive ones. Deliberately discarded drafts are removed from cached views. Opening an all-pocket result into a pocket with an unsubmitted editor keeps that editor and asks the person to finish/discard it first.

Tool, query, search scope and selection are saved as a per-pocket bookmark and restored after relaunch. Prompt/reference lists scroll the remembered selection into view where practical; arbitrary pixel scroll offsets, inspector position and filled/editor draft text are not persisted across quit. Saved scratchpads and submitted pending revisions are durable. Removing or moving the active item closes an invalid inspector/selection instead of showing another item's data.

## Search and controls

The shared search field shows **This pocket** or explicit **All pockets**. Nonempty search covers prompt labels/source and reference labels/notes across both tools; results show their pocket, tool and reviewed excerpt. It does not search attachment bytes, original filenames independently of labels, scratchpads, trash, provider memory or remote content. Whitespace-only queries show the ordinary shelf. Selecting an all-pocket result flushes/switches to the owning pocket before opening its exact item. Arrow keys and Return use the same result ordering; a visible Open control is also available.

The pocket menu creates, selects, renames, duplicates and reorders pockets, confirms deletion, and restores eligible deleted kits. Item context/Actions menus provide favourites, Move up/down, independent Duplicate, explicit Move to pocket and Delete. Organisation has native menu/button paths; reference drag continues to export original file copies. This phase does not add a new internal drag-reordering surface. The longer Actions list scrolls and follows keyboard selection. Search results expose labels, pocket identities and excerpt values through native accessibility.

## Deletion and asset lifetime

Pocket deletion confirms and retains the complete kit for exactly **seven 24-hour days** from deletion. Deleting the last live pocket creates a fresh empty pocket. Restoration keeps all original identities, scratchpad and references, appending the pocket to the live order. Expired pockets cannot be restored through this phase's UI. Expired metadata/bytes remain retained until Phase 5's ownership/recovery work verifies safe cleanup; expiry is not a destructive filesystem job.

Item Delete offers repeated in-session Undo scoped to the owning pocket. Undo restores that record/position without rolling back newer notes or another pocket. `assetReferenceCounts` accounts for live pockets, all retained trash and in-session reference Undo. Pending complete revisions retain their own reference graph. No destructive asset garbage collection runs in Phase 4: staged/orphan assets and disposable transfer exports keep Phase 3's retention rules. Accounting is not a claim that the complete live/trash/pending/export cleanup graph has been implemented; that remains Phase 5.

## Verification

Environment: Apple M3 MacBook Air, arm64, macOS **26.6.2 (25G83)**, Xcode **27.1 (27A9275)**, macOS 27 SDK, Swift 6.4/language mode 6, MainActor default isolation. The macOS 14 deployment floor remains unchanged. No new dependency or working-content network operation.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData test
```

**92 tests / 151 cases, zero failures, zero skips, no runtime warnings or Swift compiler warnings.** Final result bundle: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.29_19-31-21-+0530.xcresult`. The only build notices concern unused App Intents metadata extraction. The final acceptance build also passed. Builds/tests and native helpers ran outside the execution sandbox so Xcode and macOS UI services were available.

The Phase 4 suite exercises similar-label isolation across restart, exact scratchpads and original bytes, all three injected save failures during switching, complete pending recovery, in-session draft/filled-value isolation, cached discard and safe search navigation, interrupted trash recovery, both metadata-only search scopes, independent duplication/move, shared-digest ownership, owner-scoped Undo, persisted ordering/favourites/byte counts, navigation bookmarks, the exact seven-day boundary and schema-4/legacy-journal migration. All Phase 2–3 regressions run too.

Native checks use a separately identified acceptance build (`ashique.nivlet.phase4acceptance`), its synthetic `phase4-final` library and the named `nivlet-verification-phase4` pasteboard. Source fixtures are generated under `/tmp`. The intended working library and general clipboard are not used. The compact grouping reference is `references/ui-ux/refbox/08-project-sections.png`; the existing launcher/ShelfStyle visual system is retained.

| Native check | Observed result |
|---|---|
| Pocket creation and isolation | Website and Writing each contain an independently saved prompt named Review. Switching from an edited Website scratchpad to Writing hid Website’s text. |
| Both search scopes | This pocket returned only Writing’s prompt. All pockets showed both Review labels with distinct pocket names and body excerpts. Choosing Website opened its exact saved body. |
| Duplicate and explicit move | A reference duplicate remained in Website while the original moved to Writing. Editing the destination note left Website’s duplicate note unchanged. |
| Pocket deletion | Cancel retained Website. Confirming deletion safely selected Writing. SQLite retained the entire Website kit in trash. |
| Native quit/relaunch | Normal termination cleared pending intent. Relaunch restored Writing, its References tool and the moved reference. |
| Restore after source removal | Deleted pockets ▸ Restore Website returned the original kit. Its note, scratchpad and static original-byte preview remained correct after deleting the disposable source. |
| Shared digest | The two independently owned references shared one SHA-256-verified original. Native metadata matched the intended live/trash ownership before restore. |
| Item Delete/Undo | Deleting the active restored reference removed its tile; Undo returned it with the original source already removed. |
| Narrow and keyboard | At 320 × 360, both results, explicit All pockets scope and Open/Return footer remained readable. Native Down then Return opened the intended Website result. |

[Recorded checks](phase4-pockets/native-checks.txt) · [All-pocket search](phase4-pockets/all-pocket-search-dark.png) · [320 × 360 search](phase4-pockets/search-320x360-dark.png)

The harness was corrected to use native menu ShowMenu actions, wait for sheets and explicitly focus the resized panel before typing. The final app now requests keyboard focus through the shell when search gains focus, and the native narrow keyboard run passed. Earlier harness misses are not counted as acceptance results. Screenshots contain synthetic fixture content only.

The local gate covers the implemented multi-project workflow. It does not close final AC-05/AC-08 release compatibility. Full VoiceOver and Full Keyboard Access, reduced-motion preference toggles, OS 14/27 runtime, Intel, large-library latency/memory, physical power loss, displays/Spaces and external app drops remain unverified here. Failure boundaries and the seven-day expiry used deterministic injection/clock fixtures rather than waiting seven days or filling the host disk. Archive validation, portable restore and destructive asset cleanup remain Phase 5; licensing/distribution remain later phases.
