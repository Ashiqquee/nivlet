# Phase 2 — Durable plain prompts and scratchpad

> **27 October 2026:** Instructions were merged into Prompts (owner decision). “Instruction” work below now means plain prompts in the single Prompts list; see [decisions](../implementation/decisions.md#instructions-merged-into-prompts-27-october-2026).

Status: **Local gate passed — 28 October 2026** · [Implementation and evidence](../implementation/phase2-persistence.md) · Outstanding Phase 1 display/handoff checks remain open.

[Phase overview](../phases.md) · [Previous](phase1_deliverables.md) · [Next: Phase 3](phase3_deliverables.md)

## Outcome

Replace sample text with a real, persistent one-pocket workflow. Users can save plain prompts, copy them exactly, and keep an autosaved note/checklist across restarts.

## Build sequence

1. Introduce versioned SQLite storage and a single initial pocket. Use pocket IDs throughout so multiple pockets do not require rewriting ownership later.
2. Implement prompt creation, editing, rename, duplicate, favourite, reorder and deletion with Undo. Clearly separate title selection from the Copy action.
3. Implement one plain-text scratchpad/checklist for the pocket. Keep temporary note state separate from prompt bodies.
4. Add visible saving/saved/error state, transactional writes and recovery of a failed draft where safe. Debounce at most 500 ms; flush on focus/pocket change, tuck and quit.
5. Implement exact reviewed-text copy through a shared platform boundary. Decide and document the exact line-ending normalisation (an open PRD decision) before writing AC-02 tests; never add hidden content or auto-paste/send.
6. Keep app storage and diagnostic logs local. Establish a small failure-injection mechanism for storage tests instead of filling the developer's actual disk.

## Deliverables

- [x] SQLite schema/versioning, repositories and one saved pocket.
- [x] Prompt list/editor, favourites/order and explicit Copy feedback.
- [x] Autosaved note/checklist, including persistent error and retry/recovery UI.
- [x] Prompt deletion Undo and last-good-data preservation on failed writes.
- [x] Meaningful storage and copy correctness tests.
- [x] `docs/implementation/phase2-persistence.md`: schema, save boundaries, recovery behavior and results.

## Verify

AC-02: compare clipboard text against the reviewed body using emoji, Unicode, long content, blank lines and mixed line endings. Empty cards are rejected. Copy confirmation says only that text was copied.

Exercise early AC-06: simulate failed transaction/disk-full conditions, interrupt a write, relaunch and confirm the last good version survives. Verify the interface never reports Saved for a failed write. Test immediate quit after editing and edit → click-away → reopen.

Check favourite/order/duplicate persistence and single-pocket notes on restart. Normal working use must succeed offline without account or permission walls.

## Demo

Create a writing-style card, favourite it, copy it into another application, write a next question in Notes, quit and relaunch. Show the same data and an honest simulated save-failure state.

## Exit gate

Plain prompts copy exactly and committed text survives ordinary restart, immediate quit and tested write failures. Failed drafts are recoverable or clearly reported without overwriting the last good data. The storage foundation is ready for templates and original-file assets.

## Scope boundary

Only one pocket is visible. No template engine, file library, archive format, cloud storage or background clipboard capture.
