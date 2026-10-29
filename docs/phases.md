# Nivlet — build phases

Implementation plan · updated 29 October 2026

Build a native Mac edge-panel utility in eight phases. First prove the panel and file handoff, then make the tools work locally, then protect users' data and prepare distribution. Each phase ends with a demonstrable result and recorded evidence.

**Current state:** The native shell builds and tests pass. Phase 2's local durability gate passes: saved plain prompts, ordering/deletion Undo, scratchpad autosave, exact copy and failed-save recovery have [recorded evidence](implementation/phase2-persistence.md). Phase 3 now adds [verified named blanks and original-file intake/retry/previews](implementation/phase3-vertical-slice.md), including a tested Finder fallback. Phase 4 remains incomplete. External drag destinations, display/Spaces behavior and other native acceptance gates remain open. See the [current UI audit](implementation/ui-audit.md) and [initial feasibility evidence](implementation/phase1-feasibility.md).

## Scope and source of truth

- [Product requirements](nivlet-product-requirements.md): intended behavior, exclusions, acceptance checks AC-01–AC-08 and open decisions.
- [Research and release scope](ai-shelf-product-research.md): positioning, evidence and Refbox references.
- [Supplied full brief](https://files.instinct.com/ipl7v9gvfnb3-brief-board-product-requirements): source PRD v0.3.
- [Refbox](https://ref.box/): design reference; do not copy its artwork or branding.

First release: prompts (plain or with fill-in blanks), reference shelf, project pockets and scratchpad. Instructions and prompts were merged into one Prompts tool on 27 October 2026 (owner decision; see [decisions](implementation/decisions.md#instructions-merged-into-prompts-27-october-2026)). No model/provider API, chat capture, auto-paste/send, OCR, sync or hosted working library. Keep the proposed US$1–3 purchase target; price, trial limits and licence terms remain open rather than silently finalised by this plan.

## How to build it

Read [the architecture](architecture.md), [native UI guide](native-ui-guide.md), [skill guide](agent-skills.md) and [captured references](../references/ui-ux/README.md) before implementation.

Use the PRD's proposed native approach: SwiftUI views, AppKit for the panel/menu bar/display behavior, SQLite metadata and app-owned original file copies. Provisional deployment target is macOS 14; Intel support requires actual test evidence. These defaults can be adjusted after the feasibility phase.

Keep the UI, window behavior and storage separate enough to test exact copying, template parsing, saves and file integrity without driving the whole interface. Use a single local application, not a model service or a web backend for working features. Add dependencies only for an identified need and record their licences/deployment support.

The component boundaries live in [the architecture](architecture.md#proposed-source-layout); implemented code lives in `Nivlet/`. Create abstractions when needed; the layout does not require a separate framework or service for every folder. Licence-signing private keys belong outside the app and repository.

## Local setup observation

Read-only preflight on 26 October 2026 found an Apple silicon host with `/Library/Developer/CommandLineTools` selected. `xcodebuild -version` failed because the active developer directory is not a full Xcode installation. A later review the same day confirmed this on macOS 26.6.2 (25G83) and found no `/Applications/Xcode*.app`. Xcode may still exist elsewhere, but it most likely needs installing. **Resolved 27 October 2026:** Xcode 27.1 (macOS 27.0 SDK, Swift 6.4) is installed and its first-launch components were repaired. Details are in the [Phase 1 evidence](implementation/phase1-feasibility.md#toolchain-setup-log).

**Current macOS:** macOS 27 "Golden Gate" was released on 14 September 2026 and runs only on Apple silicon; the development host is still on macOS 26.6.2. The provisional macOS 14 floor still covers 14 through 27. Intel Macs stop at macOS 26, so Intel support remains possible but is now a shrinking, dead-end audience; decide it with the floor. Build with the current Xcode and macOS 27 SDK, guard macOS 27-only APIs, and test the shell on macOS 27 as well as the floor version before claiming support.

Phase 1 must select/configure an existing full Xcode installation or arrange installation, then record the working toolchain. Do not change system-wide developer settings merely to execute this documentation task. Signing membership and release credentials are unresolved; ordinary local development should proceed before production signing is available.

## Phase order

| Phase | Deliverable | Exit gate | Depends on | Status |
|---|---|---|---|---|
| [1 — Native feasibility](phases/phase1_deliverables.md) | Runnable edge panel with copy and sample-file drag | Focus, display behavior and handoff have recorded results | Toolchain setup | In progress |
| [2 — Durable text tools](phases/phase2_deliverables.md) | One saved pocket, plain prompts and scratchpad | Exact copy and safe restart/save failure behavior | 1 | Local gate passed; Phase 1 checks remain open |
| [3 — Templates and references](phases/phase3_deliverables.md) | Complete one-pocket text/reference slice | Template rendering and original-file integrity verified | 2 | Local gate passed; Finder fallback tested |
| [4 — Pocket workflow](phases/phase4_deliverables.md) | Multiple pockets, search, organisation and deletion recovery | Isolation, switching and Undo/trash work | 3 | Not started |
| [5 — Ownership and recovery](phases/phase5_deliverables.md) | Portable exports, validated restore and migrations | Clean-install round trip and failure recovery pass | 4 | Not started |
| [6 — Usable beta](phases/phase6_deliverables.md) | Polished accessible app with measured compatibility | AC-01–AC-06 and AC-08 have evidence | 5 | Not started |
| [7 — Purchase and installer readiness](phases/phase7_deliverables.md) | Offline entitlement, test payment flow and signed release candidate | AC-07 plus licence/install/update recovery pass | 6; commercial choices | Not started |
| [8 — Validation and release](phases/phase8_deliverables.md) | Observed reuse, reviewed release package and authorised launch | Validation evaluated and release checklist resolved | 7; tester/release authorisation | Not started |

Run an early, read-only payment-fee/seller-eligibility assessment during Phase 1 so a US$1–3 sale is assessed before substantial work. Actual provider selection, accounts and payment integration stay in Phase 7. No delivery dates are estimated before the native spike.

## What each milestone should feel like

- After Phase 1: click an edge tab, open a panel, copy sample text and return to work.
- After Phase 2: keep actual prompts and next questions across restarts.
- After Phase 3: use plain/fill-in prompts, references and scratchpad within one pocket, with explicit copy and file attachment.
- After Phase 4: switch between projects without mixing their material.
- After Phase 5: move the complete library to a clean installation and recover it safely.
- After Phase 6: use the app comfortably by keyboard/VoiceOver and on tested displays.
- After Phase 7: verify a signed licence offline and install a tested release candidate.
- After Phase 8: have evidence of repeat use and a released app only after the release action is authorised.

## Validation coverage

| PRD acceptance check | First exercised | Final release evidence |
|---|---|---|
| AC-01 Shell | Phase 1 | Phase 6 |
| AC-02 Plain prompts | Phase 2 | Phase 6 |
| AC-03 Templates | Phase 3 | Phase 6 |
| AC-04 Files | Phase 3 | Phases 5–6 |
| AC-05 Pockets | Phase 4 | Phase 6 |
| AC-06 Recovery | Phase 2 failure handling; full Phase 5 | Phases 5–6 |
| AC-07 Offline entitlement | Phase 7 | Phase 7 release candidate |
| AC-08 Accessibility | Basic keyboard behavior from Phase 1 | Phase 6 |

Use meaningful unit/integration tests for parser rules, transaction failures, asset digests, archive validation and licence verification. Use manual/native UI checks for focus, Spaces, drag targets and accessibility. Do not claim external app compatibility based only on unit tests.

Build and test commands (run successfully on 27 October 2026 with Xcode 27.1; see [Phase 1 evidence](implementation/phase1-feasibility.md#build-and-test-commands)):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' -derivedDataPath build/DerivedData build
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' -derivedDataPath build/DerivedData test
```

## Working rules

- Start each phase by reading its deliverables and prerequisite evidence.
- Produce the smallest working result before expanding UI details.
- Keep checkboxes unchecked until the deliverable exists and its gate has evidence.
- Record toolchain, hardware, OS, tested destination versions, commands and results. A target, proposal or screenshot alone is not proof of correctness.
- Carry known limitations into the next phase and the eventual website compatibility list.
- Resolve technical defaults through the spike; defer only decisions that need owner/commercial input. Do not pause local implementation merely because publication or signing is not yet authorised.
- Prepare concrete release materials before seeking any required publication, spending or outreach approval. This task authorises writing the plan; it does not start implementation or those external actions.
- Mark a phase complete only when required outputs and its exit gate pass. External validation thresholds are proposals to evaluate honestly, not results to invent or automatically pass.

## Start here

Begin with [Phase 1](phases/phase1_deliverables.md). Prove a basic native panel with sample content before building the database, all screens or a sales website.
