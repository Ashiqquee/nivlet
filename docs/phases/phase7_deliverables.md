# Phase 7 — Installer readiness and update recovery

Status: **In progress — local preparation and recovery tests pass; signed distribution gate open** · Depends on: Phase 6 native gate and release signing

> **30 October 2026 — owner decision:** Nivlet is free with optional [Buy Me a Coffee](https://buymeacoffee.com/ashiqquee) support. Entitlement, licence, trial, merchant and payment work is dropped. AC-07 is retired. This phase covers installer trust and update recovery only.

[Phase overview](../phases.md) · [Previous](phase6_deliverables.md) · [Next: Phase 8](phase8_deliverables.md) · [Implementation evidence](../implementation/phase7-distribution.md)

## Outcome

A Developer ID-signed, notarized DMG with stapled tickets and verified manual update/recovery behavior. Local tools stay free and offline. Missing release credentials do not block packaging tooling, storage recovery tests or a concrete acceptance runbook; local ad-hoc builds do not satisfy the distribution gate.

## Prerequisites

- Complete Phase 6's native accessibility, display, focus and compatibility gate before declaring a release candidate ready.
- Confirm an existing Apple Developer Program membership, Developer ID Application identity, team, final bundle identifier and `notarytool` Keychain profile before production signing. Account creation, spending and external submissions require applicable authorization; none is implied by building a local candidate.
- Keep the provisional macOS 14 floor. Build only arm64 until Intel support is decided and tested. Record exact tested runtime versions rather than inferring compatibility from compilation.

## Build sequence

1. Produce a reproducible Release build and local DMG with honest version/architecture/status, install instructions, manifest and final checksum. Never fall back silently from Developer ID to ad-hoc signing.
2. Audit Release entitlements, Hardened Runtime, signature identity/team, architecture and deployment floor. Keep credentials outside the app/repo/artifacts. Preserve sandboxed original-file behavior.
3. Sign the app with Developer ID Application and secure timestamp. Submit to Apple when authorized; require acceptance, staple and validate the app ticket. Package/sign the DMG, notarize it, staple/validate the image ticket and assess trust. Retain failure reports and last-known-good outputs.
4. Verify the exact DMG through a read-only mount and a disposable installation copy. On a clean Mac, test a quarantined Finder install, first launch, disconnected first launch and relaunch with stapled tickets. Never ask users to disable Gatekeeper.
5. Test manual signed updates, consistent pre-migration snapshots, whole-library backups, failed-update recovery and downgrade refusal. Retain originals, pending saves and post-update edits for recovery. A database snapshot alone is not a complete backup.
6. Record concrete commands, environment, hashes, evidence and untested cases. Public launch belongs to Phase 8 and needs separate authorization.

## Deliverables

- [x] Local Release/DMG tooling with separate ad-hoc and Developer ID modes, manifest/checksum and disposable install-copy verification.
- [x] Explicit Release sandbox entitlements without debugger access, plus fail-closed artifact/signing checks.
- [x] Signed/notarized workflow and credential-handling instructions, with explicit submission and retained reports. Production execution remains untested.
- [x] Manual install/update/rollback runbook with last-known-good retention and non-destructive downgrade policy.
- [x] Same-schema restart/pending-save/whole-root recovery and future-schema refusal tests; existing migration rollback and original-integrity regression coverage.
- [ ] Actual Developer ID-signed, notarized, stapled release candidate and successful trust assessments.
- [ ] Clean-Mac quarantined installation and disconnected first launch evidence.
- [ ] Previous/new signed binary update, failed replacement and rollback evidence.
- [ ] Phase 6 native acceptance gate and final runtime compatibility evidence.
- [x] `docs/implementation/phase7-distribution.md`: free-app scope, environment, results, dependencies and open checks.

## Verify

Run the complete native regression suite and distribution-tool failure checks. Confirm originals, last-good data, recoverable pending revisions, trash and ownership survive restart/update storage boundaries. Reject newer schemas visibly and without modification. Test actual migration rollback and retained assets. Run packaging verification on the exact built image; tampered/missing artifacts, unrelated signing identities and unexpected permissions must fail.

Then execute the [manual acceptance runbook](../distribution.md#manual-release-acceptance) on a clean Mac with production signing: quarantined install, stapled offline launch, existing-data update, failed replacement and compatible rollback. Record exact OS/hardware, versions, signatures, hashes and observations. Unit tests, mounted-copy checks and local signing are distinct evidence; none proves clean-Mac Gatekeeper trust.

## Exit gate

Phase 6's native gate passes; the release candidate is actually Developer ID-signed, notarized and stapled; clean-Mac install/offline launch and real signed-update/rollback checks have passing evidence. Missing credentials or hardware may leave this phase incomplete while independent local work is complete. AC-07 and all commercial prerequisites are dropped.

## Scope boundary

No entitlement system, trial limits, account, checkout, recurring validation, cloud library or public launch. Automatic updating is optional and is not implemented for v1. No membership purchase, credential import or external submission occurs as part of local verification.
