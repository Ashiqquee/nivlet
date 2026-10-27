# Phase 8 — Observed validation and website release

Status: **Not started** · Depends on: Phase 7 release candidate and authorisation for outreach/public release

[Phase overview](../phases.md) · [Previous](phase7_deliverables.md) · [PRD](../nivlet-product-requirements.md)

## Outcome

Evidence that people can use and return to the app, plus a complete reviewable website/release package. Publish only when the release action is authorised and the required technical/commercial gates are resolved.

## Build sequence

1. Prepare a consent-based study with non-sensitive sample work, core task instructions and a manual observation sheet. Prepare recruitment text before any outreach that needs authorisation.
2. Have eight target users try open → find → copy/fill/attach → return, comparing against their existing Notes/folders/snippets workflow. Distinguish unaided completion from researcher assistance.
3. Observe return use over a week with consent; do not add silent analytics. Evaluate the PRD's proposed thresholds and record sample limitations.
4. Evaluate willingness to purchase at the disclosed US$1–3 price. Intent statements are not transactions. Real checkout/purchase evidence requires an authorised live offer; mark it untested if no live checkout exists.
5. Fix observed friction in the existing five tools, rerunning only affected checks plus required release checks. Do not use weak return use as a reason to add the excluded feature backlog automatically.
6. Prepare the actual website, footage, installer/download links, supported-Mac list, attachment-compatibility table, pricing/taxes, entitlement/update policy, privacy/refunds, support and licence recovery instructions. Review legal/commercial wording before release; this plan is not legal advice or a final policy.
7. Reconcile the release checklist against actual build/version/checksum, signing evidence, acceptance report, known limitations and payment/recovery results.
8. Once authorised, publish the reviewed package, verify the real customer install/purchase journey and retain a rollback/previous-installer route. Do not make a real purchase or send tester messages without applicable authorisation.

## Deliverables

- [ ] Anonymised, consent-based observation and return-use report.
- [ ] Validation decision: proceed, revise/retest or defer, supported by actual evidence.
- [ ] Real purchase evidence or explicitly untested commercial validation; no invented successes.
- [ ] Original demo footage showing actual app behavior.
- [ ] Reviewable website and complete policies/support/recovery information.
- [ ] Versioned release manifest, signed installer/download integrity and rollback route.
- [ ] `docs/implementation/phase8-release.md`: technical/commercial gate results, publication status and limitations.

## Validation criteria

The PRD proposes six of eight users complete the flow unaided, five use it on three separate days in a week and four choose a disclosed US$1–3 purchase when real checkout exists. These are proposed decision thresholds, not existing results or universal statistical proof.

Evaluate failures honestly. If repeat use is weak, inspect capture friction, retrieval speed, audience and existing alternatives before broadening scope. If commercial validation cannot yet be performed, keep that gate open rather than claiming all release criteria passed.

## Release checks

- [ ] AC-01–AC-08 evidence corresponds to the release candidate and supported configurations.
- [ ] No unresolved data-loss, archive-integrity, focus or paid-offline-use blocker.
- [ ] Website accurately states the five features, tested limits and separate external AI fees.
- [ ] Price/trial/seats/refunds/upgrade terms are explicit and consistent with the app.
- [ ] Signed/notarized download, first run, payment/licence delivery and recovery are verified as far as authorised.
- [ ] No private user data, production secrets or third-party artwork is shipped accidentally.
- [ ] Specific public publication has been authorised; prepare materials before requesting it when needed.

## Exit gate and reporting

Report preparation, validation and publication separately. “Ready for review” is not “released.” A launch is complete only after authorised publication and verification of the live journey. If user evidence or commercial/technical gates remain unresolved, state them and keep phase status incomplete.

## Scope boundary

No automatic tester outreach, unapproved spending, new subscriptions or launch solely because the plan exists. Optional later features remain outside this release.
