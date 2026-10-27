# Phase 3 — Fill-in prompts and original-file references

Status: **Not started** · Depends on: Phase 2 persistence gate

[Phase overview](../phases.md) · [Previous](phase2_deliverables.md) · [Next: Phase 4](phase4_deliverables.md)

## Outcome

A complete one-pocket vertical slice of all five tools. Templates render predictably and references retain original bytes even after their source files are removed.

## Build sequence

1. Implement a deterministic template parser independent of the UI: `{{field_name}}`, letter-first names, letters/digits/underscore, repeated-name sharing and individually escaped literal braces. First write down the cases the PRD leaves open: lone `{`/`}`, `{{ name }}` with spaces, `\` before a non-brace, and a literal backslash before an escaped brace. Turn each into a parameterized test.
2. Add template editor diagnostics and block saving malformed source. Separate filled drafts from saved templates; require all fields, display rendered preview and provide Reset/edit-clear warnings.
3. Use the rendered preview as the source for Copy. Do not reparse values that happen to contain token syntax.
4. Implement file picker, Finder drop and explicit image/file paste through the standard `paste:` action, which avoids the macOS pasteboard privacy alert (see the architecture). Reject folders; stage, hash and copy assets before committing successful reference metadata.
5. Deduplicate immutable bytes by digest, retain original names, labels and notes, and display per-file results with retry for failed items.
6. Add bounded image thumbnails, native preview where safe/supported, and generic fallback for other files. Keep heavy file work off the UI thread.
7. Add distinct Copy note and Drag file actions, multi-file count/names, and Reveal in Finder/manual attachment fallback. Export copies must not expose internal immutable assets to accidental mutation.

## Deliverables

- [ ] Template parser/renderer, field UI, preview and safe copy.
- [ ] Saved templates and separate filled drafts with explicit reset/edit behavior.
- [ ] App-owned asset store and staged imports with digest-based integrity.
- [ ] Reference labels/notes, thumbnails/previews, drag and manual attachment fallback.
- [ ] Explicit failure UI and bounded file handling using provisional PRD size limits.
- [ ] Parser, render/copy, asset integrity and partial-import tests.
- [ ] `docs/implementation/phase3-vertical-slice.md`: grammar examples, import outcomes and handoff matrix.

## Verify

AC-03: repeated fields, malformed/unclosed tokens, empty required values, escaped braces, Unicode, multiline values and token-like values. Confirm preview and copied text are identical; edits/reset never overwrite the saved source unintentionally.

AC-04 initial pass: import 20 mixed files, remove only disposable source fixtures, restart offline, then compare stored/exported copies by digest. Verify same-name/different-content and same-content/different-name behavior. Simulate a partial failed import and retry only failures.

Try actual manual attachment in the intended browsers/native clients where available; record versions and results rather than promising all destinations. Never execute imported scripts/active HTML or automatically upload files. Thumbnails must not replace original bytes.

## Demo

Fill a critique prompt, inspect/copy it, preview a layout reference, drag its file to an existing AI app and record the next question. Restart with source fixtures removed and demonstrate the same saved kit offline.

## Exit gate

All five tools work in one pocket. Template correctness and file integrity pass, failed imports are explicit, and at least a tested manual file handoff or Finder fallback is available.

## Scope boundary

No image understanding, OCR, prompt rewriting, automatic URLs, recursive folder ingest, model metadata parsing or automatic attachment/submission.
