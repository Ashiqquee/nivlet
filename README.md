# Nivlet

A native Mac edge panel that keeps reusable instructions, fill-in prompts, reference files and notes beside the AI app you already use.

Click a small screen-edge tab, open your local pocket, then explicitly copy text or drag a reference file into your working application.

**Status:** Native development build with a full-height edge shelf and one persistent local pocket. Users can save their own instructions/plain prompts, optionally fill named blanks, import reference files and keep notes with clickable to-dos. Build and tests pass (40 tests, 71 cases). Multiple pockets and remaining release/acceptance checks are incomplete; see the [UI audit](docs/implementation/ui-audit.md) and [checklist/edge refinement](docs/implementation/checklist-refinement.md). The owner selected Nivlet on 27 October 2026.

## First-release scope

| Tool | Intended behavior |
|---|---|
| Instructions on tap | Save labelled text cards, pin favourites, search and copy reviewed text. |
| Fill-in prompts | Fill explicit named fields, inspect the complete request and copy it without AI rewriting. |
| Reference shelf | Store original file copies with labels/notes, preview supported files and drag them out manually. |
| Project pockets | Switch between separate working kits without changing the active AI conversation. |
| Scratchpad | Keep one autosaved plain-text note/checklist per pocket. |

Working features are designed to run locally and offline. No model/provider API, API key or AI subscription is required. Users control every text/file transfer; automatic chat reading, clipboard monitoring and auto-paste/send are outside v1.

Distribution is planned through the owner's website with a one-time purchase. Price, trial limits, licence terms, visual identity and final compatibility remain proposals in the requirements.

## Documentation

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

Phase 1 needs Xcode 27.1 or later. From the repository root:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' -derivedDataPath build/DerivedData build
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' -derivedDataPath build/DerivedData test
open build/DerivedData/Build/Products/Debug/Nivlet.app
```

Or open `Nivlet.xcodeproj` and press ⌘R. Nivlet runs as a menu-bar accessory with no Dock icon: click the tab at the right screen edge, or open Nivlet again from Spotlight. [Implementation decisions](docs/implementation/decisions.md) and [Phase 1 evidence](docs/implementation/phase1-feasibility.md) record what was chosen and actually tested.

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
