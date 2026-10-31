# Nivlet

A native Mac edge panel that keeps reusable prompts (with optional fill-in blanks), reference files and notes beside the AI app you already use.

Click a small screen-edge tab, open your local pocket, then explicitly copy text or drag a reference file into your working application.

**Status:** Native development build with a full-height edge shelf and persistent project pockets. Phases 2–5 pass their local gates: durable prompts/scratchpads, named blanks, original-file references, scoped search, pocket recovery, portable export/import-as-new restore and safe retention. Build and tests pass (124 tests, 213 cases; plus 9 distribution-tool tests). See the [Phase 5 evidence](docs/implementation/phase5-recovery.md), [archive format and fixtures](docs/archive-format.md), [Phase 4 evidence](docs/implementation/phase4-pockets.md) and earlier phase records. Remaining native release checks are incomplete. The owner selected Nivlet on 27 October 2026.

## First-release scope

| Tool | Intended behavior |
|---|---|
| Prompts | One list for prompts, rules and context: save labelled text, pin favourites, search and copy reviewed text. Optional named blanks let you fill fields, inspect the complete request and copy it without AI rewriting. |
| Reference shelf | Store original file copies with labels/notes, preview supported files and drag them out manually. |
| Project pockets | Switch between separate working kits without changing the active AI conversation. |
| Scratchpad | Keep one autosaved plain-text note/checklist per pocket. |

Instructions and prompts were merged into one Prompts list on 27 October 2026 (owner decision). Existing libraries upgrade automatically, with a backup of the database taken first.

Working features are designed to run locally and offline. No model/provider API, API key or AI subscription is required. Users control every text/file transfer; automatic chat reading, clipboard monitoring and auto-paste/send are outside v1.

Nivlet is free: no purchase, trial, licence or account (owner decision, 30 October 2026). Optional support goes through [Buy Me a Coffee](https://buymeacoffee.com/ashiqquee). Distribution is a signed download from the marketing site in [`website/`](website/README.md). Visual identity and final compatibility remain proposals in the requirements.

## Documentation

Phase 8 adds a local [Next.js/Tailwind website](website/README.md), real native sample captures, a [consent-based study kit](docs/validation/README.md) and a [release review packet](docs/release/checklist.md). [Phase 8 evidence](docs/implementation/phase8-release.md) records preparation separately from the still-open validation, signing, native acceptance and publication gates.

Phase 7 adds [distribution tooling and manual update/recovery instructions](docs/distribution.md). [Distribution evidence](docs/implementation/phase7-distribution.md) distinguishes the verified local candidate from the pending Developer ID, notarization and clean-Mac gates.

| Document | Purpose |
|---|---|
| [Product requirements](docs/nivlet-product-requirements.md) | Feature behavior, scope limits, acceptance checks and open decisions |
| [Architecture](docs/architecture.md) | Components, data model, native shell, storage and recovery |
| [Build phases](docs/phases.md) | Eight implementation milestones and their deliverables |
| [Phase 1](docs/phases/phase1_deliverables.md) | Starting point: native panel and file-handoff feasibility |
| [Research](docs/ai-shelf-product-research.md) | Product rationale, competitor evidence and source limitations |
| [Native UI guide](docs/native-ui-guide.md) | Design direction and native interaction expectations |
| [Agent skills](docs/agent-skills.md) | Skill routing, upstream sources and pinned installation details |

## Development approach

The proposed stack is SwiftUI with focused AppKit bridges, SQLite metadata and app-owned original assets. macOS 14 is a provisional deployment floor; Intel and full-screen support require actual testing.

[Implementation decisions](docs/implementation/decisions.md) and [Phase 1 evidence](docs/implementation/phase1-feasibility.md) record what was chosen and actually tested.

## Running Nivlet

Requires macOS 14+ and Xcode 27.1 or later. Run every command from the repository root.

### Xcode

Open `Nivlet.xcodeproj`, select the **Nivlet** scheme and press ⌘R. Press ⌘U to run the tests.

### Command line

```sh
# Use full Xcode rather than the Command Line Tools
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Build
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' -derivedDataPath build/DerivedData build

# Test
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' -derivedDataPath build/DerivedData test

# Launch
open build/DerivedData/Build/Products/Debug/Nivlet.app

# Quit a running copy before relaunching it
osascript -e 'quit app "Nivlet"'
```

### Using the app

Nivlet runs as a menu-bar accessory with no Dock icon. To open the panel, click the tab on the screen edge, press ⇧⌘Space (unless macOS already uses that shortcut), use the menu-bar item or open Nivlet again from Spotlight.

### Debug launch options

These options only work in Debug builds:

```sh
# Sample content in a preview pocket that is not saved
open build/DerivedData/Build/Products/Debug/Nivlet.app --args -NivletPreview YES

# Open the panel on launch, optionally on a specific tool: prompts, references or notes
open build/DerivedData/Build/Products/Debug/Nivlet.app --args -NivletOpenOnLaunch YES -NivletTool prompts

# Use a separate local development library (letters, numbers and hyphens only)
open build/DerivedData/Build/Products/Debug/Nivlet.app --args -NivletDevelopmentLibrary scratch

# Force light or dark appearance for screenshots
open build/DerivedData/Build/Products/Debug/Nivlet.app --args -NivletAppearance light
```

`-NivletDevelopmentLibrary` is remembered between launches. To go back to your normal library, run `defaults delete ashique.nivlet.Nivlet NivletDevelopmentLibrary`.

## UI/UX references

The [reference index](references/ui-ux/README.md) leads to [12 Refbox reference images](references/ui-ux/refbox/README.md), including actual website screenshots and original demo-video frames. Sources, timestamps and hashes are recorded in the [capture manifest](references/ui-ux/refbox/capture-manifest.json).

Open the relevant images before interface work. They inform compactness, content hierarchy and the shelf/preview relationship; they are third-party references rather than production artwork or proof of installed-app behavior.

The [capture script](scripts/capture_refbox.py) can refresh the images. Dependencies and instructions are documented in the [Refbox reference README](references/ui-ux/refbox/README.md#refresh-captures).

## Working with agents

Read [AGENTS.md](AGENTS.md) first. [CLAUDE.md](CLAUDE.md) points to the same project guidance. Local skills live in `.agents/skills/`, including the user's design toolkit and pinned SwiftUI, macOS, concurrency and testing skills. `.claude/skills/` symlinks to them for Claude Code.

Use the relevant phase and skill references for the task. Record actual verification and leave implementation milestones incomplete until their exit gates pass.

## Repository layout

```text
Nivlet.xcodeproj          Xcode project (synchronised folders, shared Nivlet scheme)
Nivlet/                   app source: App, Platform, Features, Domain, Storage, Resources
NivletTests/              Swift Testing correctness tests
AGENTS.md                 shared project guidance
CLAUDE.md                 Claude entry point
.agents/skills/           local design and native implementation skills
.claude/skills/           symlinks to .agents/skills for Claude Code discovery
docs/                     requirements, architecture, guides and phase overview
docs/phases/              per-phase deliverables
docs/implementation/      decisions and measured phase evidence
references/ui-ux/         attributed visual references and capture provenance
references/skills/        dated skill-selection research
scripts/                  reference-capture tooling
```

The root `.gitignore` excludes local build output, caches, user settings and common signing-secret formats. Documentation, skills, screenshot references, shared schemes and dependency lockfiles remain eligible for version control.
