# Project agent skills — selection and use

Researched 26 October 2026 · [root instructions](../AGENTS.md) · [architecture](architecture.md) · [native UI guide](native-ui-guide.md)

The user's existing `.agents/skills/` collection is preserved. Five native Apple skills have been added locally using pinned upstream commits: two on 26 October 2026 during planning, plus Swift Concurrency, Swift Testing and Apple HIG added the same day during review. No global skill installation or modification of the existing design skills was needed.

## Selected skills

| Skill | Use here | Adoption observed | Source |
|---|---|---|---|
| [SwiftUI Expert](../.agents/skills/swiftui-expert-skill/SKILL.md) | State/data flow, view identity, layout, accessibility, native scenes/windows and measured performance | Skills registry about 35.1K–35.2K installs; GitHub API 3,760 repository stars | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill), MIT |
| [macOS Design Guidelines](../.agents/skills/macos-design-guidelines/SKILL.md) | Keyboard/menu commands, panel/window expectations, pointer behavior, semantic appearance and native accessibility | Registry about 4.3K installs; GitHub API 625 repository stars | [ehmo/platform-design-skills](https://github.com/ehmo/platform-design-skills), MIT |
| [Apple HIG](../.agents/skills/apple-hig/SKILL.md) | Current macOS 27-era HIG detail: panels, windows, the menu bar, menus, drag and drop, focus, undo, search and materials | GitHub API 685 repository stars | [justinwetch/HIGAgentSkills](https://github.com/justinwetch/HIGAgentSkills), MIT plus NOTICE |
| [Swift Concurrency](../.agents/skills/swift-concurrency/SKILL.md) | Main-actor UI, the serial metadata store, off-main hashing/copying/thumbnails, cancellation and stale-save protection (Phases 2–5) | GitHub API 1,694 repository stars | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill), MIT |
| [Swift Testing](../.agents/skills/swift-testing-expert/SKILL.md) | Parser, storage-failure, digest, archive and licence tests; parameterized grammar cases; parallel-safe isolation | GitHub API 476 repository stars | [AvdLee/Swift-Testing-Agent-Skill](https://github.com/AvdLee/Swift-Testing-Agent-Skill), MIT |

Sources: [SwiftUI registry entry](https://www.skills.sh/avdlee/swiftui-agent-skill/swiftui-expert-skill), [macOS registry entry](https://www.skills.sh/ehmo/platform-design-skills/macos-design-guidelines), the public repositories and GitHub repository API. Search command used: `npx skills find macos`. Values are a dated snapshot; CLI/web rounded counts differed slightly during research. Installs and repository stars do not establish active-user counts or quality.

SwiftUI Expert was selected for its relevant macOS references and availability-aware implementation guidance. The macOS skill fills the desktop-interaction gap in the user's broader design toolkit. Swift Concurrency and Swift Testing come from the same author as SwiftUI Expert and cover the architecture's concurrency rules and the required correctness tests, which the original two skills only touch on. All five are community-maintained skills, not official Apple policy.

### macOS 27 currency

macOS 27 "Golden Gate" was released on 14 September 2026. The macOS Design Guidelines skill was last updated upstream on 19 March 2026, before WWDC26, so it does not reflect macOS 27 HIG changes. Apple HIG distils Apple's HIG as of 12 September 2026, which includes them; for example, menus should now use icons "sparingly and with purpose", reversing macOS 26. Use Apple HIG for specific, current guidance, and macOS Design Guidelines for its compact desktop checklist. Where they disagree, Apple HIG wins, and Apple's live HIG wins over both.

Apple HIG's MIT licence covers only its code and original text. Its reference files are distilled from Apple's HIG, which remains Apple's material (see its `NOTICE`). Treat them as internal agent reference, like the Refbox captures, and do not ship or republish them.

Apple HIG loads 16 foundation files for every design or review task, so it costs a lot of context. Invoke it for platform-specific questions or reviews rather than for small copy or spacing tweaks. Its iPhone Duo `/duo` workflow and opt-in enforce mode are irrelevant to this Mac app. Its install note asks agents to copy `commands/duo.md` into a host command directory; do not do that.

## Installation provenance

| Local folder | Upstream path | Pinned commit |
|---|---|---|
| `swiftui-expert-skill` | `skills/swiftui-expert-skill` | `204dba7c67256a8b707ee3fbc5759a824191974f` |
| `macos-design-guidelines` | `skills/macos` | `dc2be825d8b439caea78e9eaa8fb3ac23b0ff3e9` |
| `apple-hig` | repository root, runtime files from its `shipping-manifest-2026-09-27.json` | `2206ff935b4affa9ad249a5399a3e8e29f5f6edd` |
| `swift-concurrency` | `skills/swift-concurrency` | `d5770817d2622e1585b1f7eaebc791a9cb0959c8` |
| `swift-testing-expert` | `swift-testing-expert` | `798e9b1a2bcac164d4f0c781908199e754f0bab6` |

[Installed-file hashes](agent-skills-lock.json) record the third-party skills only. [Research metadata](../references/skills/research.json) records candidates, metrics and timestamps. Each upstream MIT `LICENSE` lives at its repository root and has been copied into the installed skill folder. Upstream helper scripts were downloaded as part of the skill; they were not executed during installation.

Review on 26 October 2026: every installed file of the first two skills matched upstream at its pinned commit, and both pins were still upstream `HEAD`.

Refresh intentionally: inspect the new source/commit, preserve licence notices, update the local copy and hashes, then check references. Do not auto-update a pinned skill while doing an unrelated feature change.

## Existing skill routing

| Existing skill | Relevant job |
|---|---|
| `better-accessibility` | Focus order, action labels, hit areas, keyboard/VoiceOver and motion |
| `better-layout` | Grouping, reading order, panel density and progressive disclosure |
| `better-writing` | Precise copy, field names, error recovery and honest clipboard feedback |
| `better-typography` | Text hierarchy, wrapping, truncation and readable compact rows |
| `better-colors` | Semantic tokens, contrast and light/dark behavior |
| `better-ui` | Optical alignment, nested radii, surface depth and motion polish |
| `better-interface` | An explicitly needed complete interface review across the owners |
| `interface-review` | User-requested change-scoped review; preserve its invocation policy |
| `explain-interface` | Explain a rendered surface/reference when requested |
| `variant` | Explore variations when the task calls for alternatives |
| `break` | Adversarial interaction checks when deliberately requested/appropriate |

Keep existing invocation policies. Read the owning skill before applying its rules rather than relying on the table as a substitute.

## How to apply the native skills

1. Read the PRD, architecture and requested phase; inspect actual screenshots before interface work.
2. Use macOS Design Guidelines for the relevant native surface, not every rule in its large entry point. For current or specific rules (panels, menu bar, menus, drag and drop, focus, materials), check Apple HIG's matching `references/hig/` file.
3. From SwiftUI Expert, load topic references only as needed. Particularly relevant files: `references/macos-scenes.md`, `references/macos-window-styling.md`, `references/macos-views.md`, `references/focus-patterns.md` and `references/accessibility-patterns.md`.
4. Use `swift-concurrency` for actor isolation, background file work, cancellation and Sendable diagnostics. Use `swift-testing-expert` when writing parser, storage, digest, archive or licence tests. XCTest remains the tool for UI automation and performance metrics.
5. Use a focused `better-*` owner for a specific design issue; use `better-interface` when a full review is actually intended.
6. Verify declarations/availability against the real SDK and official Apple docs. Verify behavior on the app, not just a skill example.

## Project-specific interpretation

The app is a constrained utility panel with provisional macOS 14 support. Generic rules that every app needs multiple full-size windows, every standard menu, traffic lights or new platform integrations do not automatically fit. Preserve this product's deliberate tab/panel contract. Skills cannot add Spotlight indexing, share extensions, notifications or scripting to v1 without a task requiring them.

The concurrency and testing skills assume current toolchains. Under the macOS 14 floor, `Mutex` (macOS 15+) and other newer runtime APIs need availability gating or an actor/lock alternative. The concurrency skill also tells agents to confirm the project's Swift language mode, strict-concurrency level and default actor isolation before giving advice. Record those settings in Phase 1's `decisions.md` so later agents don't have to guess.

Do not apply iOS defaults, newer-only scene APIs or arbitrary Liquid Glass. The selected SwiftUI skill itself advises using Liquid Glass only when requested. Newer APIs need both a compatible SDK and runtime gating/fallbacks; a runtime check cannot make an older SDK compile an unknown declaration.

Translate web-oriented existing skills into native equivalents. ARIA/CSS/DOM examples are not SwiftUI implementation instructions. Existing density and references matter; avoid introducing a new visual direction simply to satisfy generic aesthetics.

## Other candidates considered

- [Paul Hudson's SwiftUI Pro](https://github.com/twostraws/SwiftUI-Agent-Skill): 6,359 repository stars observed through GitHub API; MIT. A credible alternative with substantial overlap. Its current instructions include newer/iOS/toolchain defaults, so it was not added on top of the selected implementation skill. More stars did not outweigh fit and duplication.
- [Wholiver's SwiftUI Design Skill](https://github.com/Wholiver/swiftui-design-skill): 209 repository stars observed; MIT. Covers visual direction but overlaps with the user's design skills and contains a macOS 15+ prerequisite plus prescriptive variation/style rules. Not installed for the macOS 14 utility brief.

- [twostraws Swift Concurrency](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) and [Swift Testing](https://github.com/twostraws/Swift-Testing-Agent-Skill) skills: MIT, 576 and 471 stars observed. Not installed because each overlaps the chosen AvdLee skill.
- OpenAI's [`appkit-interop` skill](https://github.com/openai/plugins/tree/main/plugins/build-macos-apps/skills/appkit-interop) has directly relevant references: `window-panels.md`, `drag-drop-pasteboard.md` and `responder-menus.md`. The repository has no licence file, so it is not vendored here. Agents may read it upstream as reference material during Phase 1.

These are fit decisions for this repository, not universal quality rankings. No skill can replace native runtime testing or guarantee good design.

## Discovery

`.agents/skills/` is the single source of truth. Claude Code only discovers project skills under `.claude/skills/`, so each skill has a relative symlink there, `.claude/skills/<name>` → `../../.agents/skills/<name>`. That makes the skills discoverable and invocable as `/<name>`, and honours their `disable-model-invocation` settings without duplicating any files. When adding or removing a skill, update its symlink too. Other agents read the entry points by path, as `CLAUDE.md` and `AGENTS.md` instruct.
