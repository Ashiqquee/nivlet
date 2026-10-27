# Phase 1 — Native feasibility and project foundation

Status: **Not started** · Depends on: working full Xcode toolchain

[Phase overview](../phases.md) · [PRD](../nivlet-product-requirements.md) · [Next: Phase 2](phase2_deliverables.md)

## Outcome

A runnable native Mac app with a single screen-edge tab and panel. Prove open/tuck/pin, editable sample content, explicit text copy and original-file handoff before committing to the complete implementation.

## Build sequence

1. Locate/configure full Xcode (current release, with the macOS 27 SDK) and record macOS, hardware, Xcode and SDK versions. Plan test coverage on macOS 27 and on the macOS 14 floor (a VM or second volume is enough for the floor). The initial preflight selected Command Line Tools and could not run `xcodebuild`; do not assume Xcode is absent or silently change global settings.
2. Create `Nivlet.xcodeproj`, the `Nivlet` Mac scheme and app entry. Use SwiftUI hosted by an AppKit-managed panel. Keep identifiers provisional until branding/signing decisions are made.
3. Implement one tab, one panel, menu-bar open/quit, left/right placement, resize and Pin. Start with static instruction/template/reference/note examples rather than storage.
4. Exercise keyboard focus, Escape hierarchy and click-away. Edit a sample field before clicking another application; its click must reach it and no text may be typed into the wrong app.
5. Exercise display bounds, unplug/reconnect if hardware permits, sleep/wake, current Space and full-screen limitations. Add normal desktop/menu-bar fallback for unsupported overlay cases.
6. Copy sample text explicitly; drag one known sample file and exercise Finder fallback. Do not auto-paste/send or infer receipt by the destination.
7. Inspect signing/notarization prerequisites and perform a read-only assessment of low-price payment feasibility. Record unavailable resources as later dependencies rather than spending or creating accounts.

Use the PRD's proposed geometry as adjustable starting values, not immutable design decisions. Keep the optional global shortcut disabled until configured/conflict-checked; validate an available shortcut mechanism without requiring unrelated permissions. The PRD's Option-Space proposal conflicts with the ChatGPT Mac app and with non-breaking-space typing (see PRD §07), so record candidate alternatives here.

When creating the project, record the Swift language mode, strict-concurrency level and default actor isolation in `decisions.md`. New Xcode projects may default to main-actor isolation, and the concurrency skill relies on knowing this. The unlicensed OpenAI [`appkit-interop`](https://github.com/openai/plugins/tree/main/plugins/build-macos-apps/skills/appkit-interop) references on panels, drag/pasteboard and responder menus are useful upstream reading for this spike. Verify them against Apple docs.

## Deliverables

- [ ] Buildable native project and documented local run command.
- [ ] Single tab/panel, open/tuck/pin and menu-bar fallback.
- [ ] Sample text editing/copy and sample-file drag/Finder fallback.
- [ ] Left/right, resize and visible-bounds handling; feasible display settings.
- [ ] `docs/implementation/phase1-feasibility.md`: tested behaviors, failures and evidence.
- [ ] `docs/implementation/decisions.md`: provisional architecture/OS floor, display/Space rules, shortcut mechanism, dependency rationale and open signing/commercial questions.

Evidence document paths are outputs to create during implementation; they do not exist merely because this plan names them.

## Verify

Exercise AC-01 and basic AC-08 manually: click, keyboard, edit then dismiss, pin, resize, repeated open/close, resolution/wake and external display changes where available. Record untested hardware cases rather than treating them as passes.

Inspect explicit clipboard output and sample-file integrity at a destination. Record exact OS/app/browser versions and permissions prompted. No Accessibility, Screen Recording or Full Disk Access should be necessary for the manual workflow.

Record a short panel demo and reproduce the build from a clean derived-data directory. Do not expand testing to every destination until the basic mechanism works.

## Exit gate

The tab opens the correct panel, sample editing is safe, copy/drag works or has an explicit fallback, and focus/display limitations are documented. Any lost-edit, stolen-click or duplicate-window issue blocks progress to feature work. Unavailable production signing does not block ordinary local development.

## Scope boundary

No database, complete CRUD, model integration, accounts or sales-site build. Full-screen support and Intel support remain evidence-based decisions.
