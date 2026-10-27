# Phase 4 — Project pockets, search and organisation

Status: **Not started** · Depends on: Phase 3 one-pocket vertical slice

[Phase overview](../phases.md) · [Previous](phase3_deliverables.md) · [Next: Phase 5](phase5_deliverables.md)

## Outcome

Users switch between complete project kits, find the right item quickly and organise their material without accidental crossover or unrecoverable deletion.

## Build sequence

1. Add pocket create, rename, reorder, duplicate and switch. Each owns its instructions/templates/references and one scratchpad.
2. Flush edits on switching and restore view/scroll where practical. Keep filled drafts scoped to their template/pocket; switching must not leak values into another kit.
3. Implement search over labels, instruction/template bodies and reference notes in the active pocket. Add clearly indicated All pockets scope; choosing a result changes the local pocket when necessary.
4. Finish favourites, reorder, independent duplication and explicit move between pockets with menu alternatives to drag.
5. Implement confirmation and seven-day recoverable trash for pocket deletion; single-item Undo. Preserve assets referenced by trash or pending operations.
6. Add clear empty/no-result states and safe behavior when deleting/moving an active item. No nested hierarchy or live cross-pocket links is required.

## Deliverables

- [ ] Pocket switcher and complete local kit isolation.
- [ ] Active-pocket and explicit all-pocket search with readable results.
- [ ] Favourites, reorder, duplicate/move controls and keyboard alternatives.
- [ ] Pocket trash/restore and item Undo with asset-reference accounting.
- [ ] Meaningful isolation/switching/search/lifecycle tests.
- [ ] `docs/implementation/phase4-pockets.md`: ownership rules, search fields and lifecycle results.

## Verify

AC-05: use two pockets with deliberately similar item labels and different bodies/files. Switch while editing notes and templates, search each scope, duplicate, move, delete and Undo; then quit/relaunch immediately.

Confirm all-pocket search does not imply global AI memory, search does not inspect hidden file contents, and moves do not silently change a copy's independent metadata. Test removing the active pocket and restoring it from trash, including its original reference bytes.

Check asset lifetime when two independent references share a digest: deleting one must not remove the other's content. Defer destructive garbage collection until Phase 5 verifies the full live/trash/export ownership graph.

## Demo

Switch between Website and Writing pockets containing similar labels, retrieve the intended instruction, move a reference explicitly and recover a deleted pocket. The existing AI application remains untouched.

## Exit gate

Pocket isolation, search, safe switching, organisation and recoverable deletion pass. A usable multi-project workflow exists without combining or sending material automatically.

## Scope boundary

No provider-project synchronisation, automatic app-based switching, cross-pocket live links, semantic search, indexing attachment contents or hosted sharing.
