# Phase 4 — Project pockets, search and organisation

Status: **Local gate passed · 29 October 2026** · Depends on: Phase 3 one-pocket vertical slice

[Phase overview](../phases.md) · [Previous](phase3_deliverables.md) · [Next: Phase 5](phase5_deliverables.md)

## Outcome

Users switch between complete project kits, find the right item quickly and organise their material without accidental crossover or unrecoverable deletion.

## Build sequence

1. Add pocket create, rename, reorder, duplicate and switch. Each owns its prompts, references and one scratchpad.
2. Flush edits on switching and restore view/scroll where practical. Keep filled drafts scoped to their template/pocket; switching must not leak values into another kit.
3. Implement search over labels, prompt bodies and reference notes in the active pocket. Add clearly indicated All pockets scope; choosing a result changes the local pocket when necessary.
4. Finish favourites, reorder, independent duplication and explicit move between pockets with menu alternatives to drag.
5. Implement confirmation and seven-day recoverable trash for pocket deletion; single-item Undo. Preserve assets referenced by trash or pending operations.
6. Add clear empty/no-result states and safe behavior when deleting/moving an active item. No nested hierarchy or live cross-pocket links is required.

## Deliverables

- [x] Pocket switcher and complete local kit isolation.
- [x] Active-pocket and explicit all-pocket search with readable results.
- [x] Favourites, reorder, duplicate/move controls and keyboard alternatives.
- [x] Pocket trash/restore and item Undo with asset-reference accounting.
- [x] Meaningful isolation/switching/search/lifecycle tests.
- [x] `docs/implementation/phase4-pockets.md`: ownership rules, search fields and lifecycle results.

## Verify

AC-05: use two pockets with deliberately similar item labels and different bodies/files. Switch while editing notes and templates, search each scope, duplicate, move, delete and Undo; then quit/relaunch immediately.

Confirm all-pocket search does not imply global AI memory, search does not inspect hidden file contents, and moves do not silently change a copy's independent metadata. Test removing the active pocket and restoring it from trash, including its original reference bytes.

Check asset lifetime when two independent references share a digest: deleting one must not remove the other's content. Defer destructive garbage collection until Phase 5 verifies the full live/trash/export ownership graph.

## Demo

Switch between Website and Writing pockets containing similar labels, retrieve the intended prompt, move a reference explicitly and recover a deleted pocket. The existing AI application remains untouched.

## Recorded evidence

[Implementation and evidence](../implementation/phase4-pockets.md): 92 tests / 151 cases pass, plus native two-pocket search, reference duplicate/move, deletion Cancel/confirm, item Undo, immediate restart and complete pocket restoration after source removal. Navigation bookmarks survive relaunch; editor/filled drafts stay scoped in session. Asset cleanup and archive restore remain Phase 5. Full VoiceOver/OS/display compatibility remains open.

## Exit gate

Pocket isolation, search, safe switching, organisation and recoverable deletion pass. A usable multi-project workflow exists without combining or sending material automatically.

## Scope boundary

No provider-project synchronisation, automatic app-based switching, cross-pocket live links, semantic search, indexing attachment contents or hosted sharing.
