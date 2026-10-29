# Phase 7 — Offline entitlement and installer readiness

Status: **Not started** · Depends on: Phase 6 beta gate and required commercial/signing decisions

[Phase overview](../phases.md) · [Previous](phase6_deliverables.md) · [Next: Phase 8](phase8_deliverables.md)

## Outcome

A release candidate with locally verified paid entitlement, a working test purchase/recovery journey and a signed/notarized installer when release credentials are available. Buying once must not create a recurring dependency for local tools.

## Decisions and prerequisites

Prepare a concrete decision sheet before external setup: final price within the US$1–3 target or an explicitly raised alternative, currency/tax presentation, merchant eligibility/fees, trial limits, seat policy, refund/recovery tradeoffs and future-upgrade terms.

The PRD proposes US$2 before applicable tax; one person/two personal Macs; and a non-expiring trial with one pocket, 10 prompts and 10 references (instructions were merged into prompts on 27 October 2026). Do not silently turn proposals into final commercial terms. Verify current Indian seller onboarding/payout requirements and exact fees during implementation.

Local verifier, test licences, installer scripts and checkout specifications can be prepared before provider accounts or production credentials exist. Selecting a merchant, spending, issuing real paid licences or making external changes requires the applicable task authorisation; document any specific dependency without blocking independent work.

## Build sequence

1. Document per-sale economics, supported buyers/currencies, tax/refund responsibilities and recovery process. If the target price does not work, raise that decision; do not quietly add a subscription.
2. Define a versioned signed licence payload and local verifier using established signature primitives. Put only the verification public key in the app. Keep issuer private keys outside the repository, build artefacts and application.
3. Support explicit licence-file import, honest entitlement status and offline validation. Base-app paid use has no periodic renewal or expiry tied to server availability/date changes.
4. Apply agreed trial limits at creation/import boundaries without destroying or trapping existing content. Existing reading/copy/export/recovery must remain available if limits change; define oversized archive import behavior explicitly.
5. Build a test-only licence issuer/fixtures and test checkout/delivery/recovery flow with the selected provider when authorised. Separate licence recovery data from pocket contents.
6. Package a Developer ID-signed, notarized DMG with stapled ticket when credentials are available. Check distribution entitlements/settings and a clean-Mac Gatekeeper install.
7. Test manual signed updates, migration snapshots, rollback and failed-update behavior. Optional automatic updater is not required for v1.

Two-Mac terms cannot be reliably machine-counted by a purely offline verifier without additional mechanisms. Record the chosen trust/enforcement tradeoff instead of claiming impossible enforcement or silently adding recurring activation. Refund revocation has similar offline tradeoffs.

## Deliverables

- [ ] Reviewed commercial decision sheet and fee economics; merchant choice explicitly recorded.
- [ ] Signed licence format, issuer key-handling instructions, fixtures and local verification tests.
- [ ] Offline licence import/status, agreed trial behavior and non-destructive limit handling.
- [ ] Test checkout → receipt → licence → recovery evidence, without leaking production secrets.
- [ ] Reproducible installer/signing/notarization instructions and release candidate when credentials permit.
- [ ] Clean-Mac installation, update/rollback and offline entitlement evidence.
- [ ] `docs/implementation/phase7-distribution.md`: final choices, dependencies, AC-07 and distribution results.

## Verify

AC-07: import a valid paid licence, disconnect, change date/time zone and relaunch. Test valid, tampered, wrong-key, malformed and unsupported licences. Signature failures must not modify or erase working data. No issuer private key ships in the binary.

Test trial ceilings, duplicates, archive imports and entitlement changes against the agreed non-destructive policy. Recovery cannot depend on emailing private pocket content. Refund/recovery behavior must match the stated offline limitations.

On a clean Mac verify installer trust, first launch, offline launch with stapled ticket, existing-data update and failed-update recovery. No normal path should ask users to disable Gatekeeper. Record actual signing/notarization results; local unsigned builds are not equivalent evidence.

## Exit gate

AC-07 passes, trial/licence terms are resolved, test delivery/recovery works, and the release candidate passes actual signing/install/update checks. Missing production credentials or unresolved economics may leave this phase incomplete while code/test preparation continues.

## Scope boundary

No subscription, AI credits, cloud library, hidden periodic licence checks or public launch during this phase. A provider test flow is not proof of live sales.
