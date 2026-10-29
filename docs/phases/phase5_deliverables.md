# Phase 5 — Portable ownership and recovery

Status: **Not started** · Depends on: Phase 4 pocket ownership/lifecycle

[Phase overview](../phases.md) · [Previous](phase4_deliverables.md) · [Next: Phase 6](phase6_deliverables.md)

## Outcome

A complete library can be exported, restored on a clean installation and recovered after tested failures. Migration and asset cleanup cannot silently destroy users' work.

## Build sequence

1. Define a versioned portable manifest for one/all pockets plus original assets. Include labels, order, prompt sources and blank settings, reference notes, scratchpads/checklists and asset digests.
2. Specify what is deliberately excluded, such as paid entitlement and machine/display preferences. Keep device-specific state separate; restoring must preserve actual working content.
3. Export from a consistent snapshot; pin assets during export. Preview contents and disclose that exports can contain private material.
4. Restore into staging, validate paths/schema/digests/file counts/expanded sizes, then commit transactionally. Reject traversal, symlink escape, malformed manifests, unsupported versions and archive bombs.
5. Preview counts and import as new pockets with independent IDs/metadata. Never silently merge or overwrite existing work; cancellation/failure leaves the destination unchanged.
6. Add recoverable snapshots before schema migrations and test rollback instructions. Finish asset cleanup only after checking live, trash and pending-export references.
7. Recheck interrupted saves/imports, low space, recovery journal behavior and safe diagnostic logging.

## Deliverables

- [ ] Portable one-pocket/all-pocket export and validated import-as-new restore.
- [ ] Versioned schema/manifest documentation and disposable fixtures.
- [ ] Migration snapshot and recovery/rollback procedure.
- [ ] Safe asset retention/cleanup across live data, trash and exports.
- [ ] Archive validation, atomic restore, byte integrity and failure-recovery tests.
- [ ] `docs/implementation/phase5-recovery.md`: round-trip evidence and recovery instructions.

## Verify

AC-06: export a populated multi-pocket library and restore into a clean disposable app-data location. Compare all working text, checklist state, ordering and original-file digests. Do not overwrite the developer's real library for testing.

Exercise unsupported schemas, tampered assets, duplicate/malicious paths, symlink entries, expanded-size limits, insufficient space and interruption. Failed restore must neither write outside staging nor leave partially visible pockets. Restoring again creates explicit new pockets rather than hidden merges.

Recheck AC-04 original bytes after migration/restore. Verify garbage collection cannot remove an asset retained by another pocket, trash or in-progress export. Record which recovery scenarios are covered and remaining limitations.

## Demo

Export a real sample kit, start a clean local installation/data directory, import it and use its prompts and reference files. Demonstrate refusal of an invalid archive without changing the existing library.

## Exit gate

Clean-install round trip, corruption/failure handling, migration recovery and asset retention pass. Users can own and recover their working data without an account or server.

## Scope boundary

No cloud backup, automatic folder sync or collaboration. Export archives do not confer a paid licence or bypass its verification.
