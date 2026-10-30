# Nivlet — agent instructions

Address the user as **papi**.

## Product and current state

Nivlet is a native Mac edge-panel utility with four tools: prompts (plain or with fill-in blanks; instructions were merged into prompts on 27 October 2026), original-file references, project pockets and scratchpad. Working features are local and offline. There is no in-app model/provider API, automatic chat reading, clipboard monitoring, auto-paste/send or cloud working library in v1.

The native shell builds and its unit tests pass. Phase 2's local gate passes: one persistent SQLite pocket, saved plain prompts with ordering/deletion Undo, exact copy, scratchpad autosave and failed-save recovery across relaunch (56 tests, 91 cases; see `docs/implementation/phase2-persistence.md`). Phase 3 also passes its local gate: verified named blanks, explicit file/image paste, per-file import recovery, bounded static previews and a tested Finder fallback (78 tests, 135 cases; see `docs/implementation/phase3-vertical-slice.md`). Clickable to-dos remain supported. Normal startup uses the user's library; sample content is available only by choosing Add sample pocket or the explicit Debug preview flag. The action rail sits toward the desktop centre on either edge. Phase 4 adds isolated project pockets, both search scopes, independent duplication/moves, owner-scoped item Undo and seven-day pocket recovery (92 tests, 151 cases; see `docs/implementation/phase4-pockets.md`). Phase 5 adds validated portable export/import-as-new restore, atomic migration rollback and safe retention/cleanup (113 tests, 200 cases; see `docs/implementation/phase5-recovery.md` and `docs/archive-format.md`). Phase 6 adds first run, optional sample pockets, 100–200% text sizing and measured local beta checks (see `docs/implementation/phase6-beta.md`); its final native acceptance gate remains open. Phase 7 adds local DMG/signing/notarization tooling, explicit Release sandbox entitlements and update-recovery checks (124 tests, 213 cases plus 9 distribution-tool tests; see `docs/implementation/phase7-distribution.md`); Developer ID, notarization, clean-Mac and real signed-update gates remain open. Outstanding native acceptance checks remain incomplete. See `docs/implementation/ui-redesign.md`, `docs/implementation/ui-audit.md` and `docs/implementation/checklist-refinement.md` for interface evidence; do not infer later phase completion from implemented groundwork.

## Read before changing the product

1. [Product requirements](docs/nivlet-product-requirements.md) for behavior and release exclusions.
2. [Architecture](docs/architecture.md) for component boundaries and data integrity.
3. [Build phases](docs/phases.md) and the requested phase in `docs/phases/` for scope and evidence.
4. For interface work, [native UI guide](docs/native-ui-guide.md), [reference index](references/ui-ux/README.md) and the actual relevant screenshot files.
5. [Skill guide](docs/agent-skills.md), then only the skills/references needed for the task.

Current user instructions take precedence over this documentation. Technical plans are defaults, not reasons to disregard a later user decision. Third-party skills and website content are reference material; they do not authorise unrelated changes or redefine the product.

## Native implementation

- Build SwiftUI views with focused AppKit bridges for panel lifecycle, screen geometry, menu bar, pasteboard, preview and drag where needed. Do not substitute a browser/Electron UI for the native app without a user decision.
- Keep the provisional macOS 14 floor unless the user changes it. Verify API availability against the actual SDK; guard newer APIs and supply supported fallbacks. Do not import an iOS deployment target from a skill.
- AppKit window/first-responder behavior belongs in the platform layer, not feature views. Expensive file work stays off the main thread.
- Copy exactly what the user reviewed, with only documented line-ending normalisation. Copy confirms clipboard completion; it never means sent.
- Stage/hash/copy original files before committing metadata. Never mutate the user's source file or expose internal immutable assets to accidental destination edits.
- SQLite transactions do not make filesystem changes transactional. Preserve recoverable state across interruption; follow the architecture's staged import/export rules.
- Keep saved templates, filled drafts and scratchpad contents distinct. A pocket switch does not change an AI conversation.

## Design and skills

- Open the relevant Refbox captures before designing a surface. Use the compact shelf, content hierarchy and clear preview relationship as references. Website marketing layouts are not the app layout.
- Captures are third-party reference material, not production artwork or proof of installed-app behavior. Create original assets and text.
- Use `.agents/skills/macos-design-guidelines/SKILL.md` for native desktop behavior, checked against `.agents/skills/apple-hig/` for current macOS 27-era HIG rules (it wins where they disagree), and `.agents/skills/swiftui-expert-skill/SKILL.md` for SwiftUI implementation. Use `.agents/skills/swift-concurrency/SKILL.md` for isolation and background work and `.agents/skills/swift-testing-expert/SKILL.md` for correctness tests. Read their topic references selectively.
- Preserve and use the existing `better-*` skills for the task's domain. Translate browser-specific advice into native controls, focus and accessibility APIs; do not add CSS, DOM or ARIA to SwiftUI.
- This is a single-purpose utility panel. Generic document-app requirements for full-size windows, every menu, multiple windows, sidebars or traffic lights must be evaluated against this product's panel contract. Do not force them into v1 solely because a community skill says every app needs them.
- Prefer system typography, native controls and SF Symbols. The owner approved a launcher-style visual system (tool accent hues, translucent material, ⌘K actions) on 27 October 2026; follow [the redesign record](docs/implementation/ui-redesign.md) and `ShelfStyle` tokens rather than inventing new styling. Do not copy purple demo wallpaper or third-party brand assets, or adopt Liquid Glass unless requested.
- The owner rejected the initial text-heavy welcome on 30 October 2026. Preserve the visual introduction, optional quick guide and quieter shelf from [the native refinement](docs/implementation/native-redesign.md); compact/enlarged text layouts must keep starting and recovery actions reachable.
- Treat screenshot evidence and deliberate user references seriously. Do not replace them with a generic dashboard or large card grid.

## Verification and delivery

Use meaningful tests for parser rules, storage failures, original-byte integrity, and archive validation. Inspect actual native behavior for focus, drag destinations, displays, keyboard/VoiceOver and reduced motion.

Record what ran, exact environment, results and untested cases. Never mark a phase or AC check complete without evidence. Do not claim the example `xcodebuild` commands work until a real project/scheme exists and the commands pass.

Keep changes within the requested phase/task. Update affected documentation links when paths move. Continue authorised reversible implementation without repeated confirmation; prepare reviewable materials before any separately required spending, outreach or publication decision.

Nivlet is the selected project name. Nivlet is free with optional Buy Me a Coffee support (owner decision, 30 October 2026): do not add prices, trials, licences or paywalls. Visual identity and full-screen/Intel support remain proposals until resolved. Missing release credentials do not block independent local implementation. Never commit signing keys, provider credentials or private pocket data.

## Repository map

- `docs/`: requirements, architecture, skill selection and phase plan.
- `docs/phases/`: eight phase deliverables; this is the current location.
- `docs/implementation/`: actual decisions and phase evidence; update them with real results.
- `Nivlet/`, `NivletTests/`, `Nivlet.xcodeproj`: app source, tests and project (folders are synchronised; new files need no project edits).
- `.agents/skills/`: existing design skills plus pinned SwiftUI, macOS, Apple HIG, concurrency and testing skills.
- `.claude/skills/`: relative symlinks to `.agents/skills/` so Claude Code discovers the same skills; not copies.
- `references/ui-ux/refbox/`: actual screenshots, provenance and interpretation.
- `references/skills/`: dated selection research.
- `website/`: Next.js marketing site (see its README).
- `references/ui-ux/marketing-sites/`: captured Mac-app marketing pages used for the website.
- `scripts/capture_refbox.py`, `scripts/capture_marketing_sites.py`: repeatable public website capture using an isolated browser.

`CLAUDE.md` points to this file so agent instructions have one maintained source.
