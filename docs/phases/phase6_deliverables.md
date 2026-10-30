# Phase 6 — Accessible, polished and measured beta

Status: **In progress — local implementation and measurements; final native acceptance remains open** · Depends on: Phase 5 ownership/recovery gate

[Phase overview](../phases.md) · [Previous](phase5_deliverables.md) · [Next: Phase 7](phase7_deliverables.md)

## Outcome

A coherent beta that people can use with keyboard/VoiceOver, in light/dark appearance and on the tested desktop configurations. Compatibility and performance claims have recorded evidence.

## Build sequence

1. Apply the Refbox-inspired compactness using original artwork and native typography/materials. Keep text readable, action names clear and previews inside the panel.
2. Finish first run: removable sample/blank pocket, open/tuck/pin explanation, edge/display settings and optional conflict-checked shortcut. Do not introduce account or permission walls.
3. Complete keyboard navigation, focus indicators, VoiceOver labels, enlarged text, contrast and reduced motion. Escape must back out one level before tucking; outside clicks still reach their destination.
4. Recheck panel bounds on display detach/reconnect, wake, resolution changes, Spaces, full-screen apps and Stage Manager where available. Publish an internal tested/unsupported/untested matrix.
5. Measure warm opening, search/copy feedback, pocket loading, idle CPU and thumbnail responsiveness on documented hardware. Fix measured bottlenecks, keeping file work off the main thread.
6. Consolidate acceptance evidence, address regressions and prepare a reproducible internal beta build. Keep fallback attachment and honest copy feedback visible.

## Deliverables

- [ ] Cohesive four-tool UI with complete empty/error/loading states.
- [x] First-run/sample pocket and configurable access/display behavior.
- [ ] Keyboard/VoiceOver, enlarged-text, contrast and reduced-motion verification.
- [x] OS/hardware/browser/destination compatibility matrix with limitations.
- [x] Measured performance report and build/test reproduction instructions.
- [x] [`docs/implementation/phase6-beta.md`](../implementation/phase6-beta.md): current AC-01–AC-06 and AC-08 evidence, issues and remaining checks.

## Verify

Complete the PRD acceptance flows using both ordinary mouse interaction and keyboard/VoiceOver. Manually verify destination handoff with recorded versions; unavailable Intel hardware or older OS installations remain untested, not supported by assumption.

Targets, not automatic passes: warm panel opening below 150 ms p95, search/copy feedback below 100 ms, 200-item pocket loading within one second and near-zero idle CPU. Document methodology/sample count and stress-test 1,000 items and interrupted imports. If a target cannot be met, record and resolve the discrepancy rather than inventing measurements.

Rerun correctness checks affected by polish changes and the required beta regression set. Do not keep repeating unchanged suites without a new failure/change. Inspect logs and idle network behavior for accidental content disclosure; the app's working features remain offline.

## Demo

Complete the core session with keyboard/VoiceOver, then with pointer/drag, in light and dark modes. Show recovery from a missing display and the documented full-screen fallback if needed.

## Exit gate

AC-01–AC-06 and AC-08 have reproducible passing evidence, accessibility issues are resolved and the beta's support claims match tested configurations. Any unresolved data-loss, original-byte corruption, focus or archive-validation issue blocks the next release gate.

## Scope boundary

No new product feature areas, analytics, model integration or broad support claims based on the developer's one machine. Signing, notarization and installer readiness are Phase 7. Nivlet is free; payment and entitlement work are excluded.
