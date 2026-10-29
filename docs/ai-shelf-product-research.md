# Nivlet — research and release scope

> **Historical research.** Written before 27 October 2026, when the owner merged “Instructions on tap” and “Fill-in prompts” into one Prompts tool. Read [the product requirements](nivlet-product-requirements.md) for the current scope.

Updated 27 October 2026 · based on the original Brief Board PRD v0.3

## Current direction and references

Build a local Mac utility with a discreet screen-edge tab. Opening it reveals instructions, fill-in prompts, reference files and a scratchpad, organised into project pockets. People explicitly copy text or drag files into the AI application they already use.

**Product promise:** Keep your instructions, prompts and references beside any AI app.

The supplied full brief narrows the original research proposal to five first-release tools. Linked input/output setups, automatic context assembly and outcome capture are outside this release.

| Reference | Role |
|---|---|
| [Original Brief Board product requirements](https://files.instinct.com/ipl7v9gvfnb3-brief-board-product-requirements) | Supplied PRD v0.3, dated 26 October 2026. All four source sections—Product, Experience, Engineering, and Release & sources—were read for this update. |
| [Local product requirements](nivlet-product-requirements.md) | Local adaptation of the full brief, including behavior, acceptance checks, proposals and open decisions. |
| [Build phases](phases.md) | Eight implementation phases with per-phase deliverables, checks and exit gates. |
| [Refbox](https://ref.box/) | Design/reference-board inspiration: compact media shelf, floating reference previews, economical controls and content-led presentation. |
| [Captured UI/UX references](../references/ui-ux/refbox/README.md) | Local screenshots of the public page, embedded demo frames and feature imagery, with source URLs/timestamps. The earlier conversation screenshots remain additional user references. |

The public Refbox site and conversation screenshots inform the design. The installed app has not been tested. Treat the edge tab as this product's proposed interaction; this research has not verified it as a current Refbox feature. Borrow compactness and care rather than logos, artwork, branding or an exact layout.

The owner selected Nivlet as the project name on 27 October 2026, replacing the earlier Brief Board working label. Visual identity and domain/brand clearance remain open. No app has been built or launched.

## Product and business boundaries

- Mac app downloaded from the owner's website; no App Store for v1.
- One-time payment for continued base-app use. The supplied brief targets **US$1–3**, with **US$2 before applicable tax** proposed rather than final.
- No in-app model, provider API, API key, generated prompts or AI subscription. Working features operate offline.
- Explicit copy, paste/import and file drag only. No automatic chat reading, clipboard history, upload, auto-paste or submission.
- No required app account, default analytics or cloud library.
- Checkout, licence delivery and optional update checks are distribution infrastructure with their own costs. External AI services remain separate.

The earlier $29 introductory/$39–49 regular recommendation is superseded by the supplied brief's $1–3 target. Earlier seven-day trial advice is superseded by a proposed non-expiring limited trial. Final price, trial limits and seats remain open.

## What the research establishes

The following are vendor-documented capabilities and prices observed during this research, not results from installing or benchmarking the apps. Prices may change.

| Product/category | Relevant evidence | Implication for this app |
|---|---|---|
| [Refbox](https://ref.box/) | Floating references, automatic layout, project boards, several media types, local storage, and a $39 one-time purchase. | Borrow the immediate access and compact presentation. The visual container alone will not distinguish an AI product. |
| [Raycast Snippets](https://www.raycast.com/core-features/snippets) | Searchable text, insertion, expansion, and dynamic placeholders. | Saving text and filling variables are established expectations. They are useful features, but weak differentiation. |
| [Refrain](https://refrainformac.com/) | A $9.99 one-time Mac utility for finding and copying reusable text stored in a Markdown file. | A simple prompt clipboard competes with inexpensive, focused utilities. |
| [Promptery](https://promptery.app/) | Prompt storage, reusable context and Skills; one-time tiers advertised at $5, $19, and $49. | “A portable AI memory bank” already has direct competition. |
| [ThatPrompt](https://thatprompt.ai/) | $39 lifetime licence, prompt search, and enhancement using a downloaded local model. | Offline prompt enhancement is already offered elsewhere. It would introduce setup and model support work here. |
| [Dropover](https://dropoverapp.com/) | A temporary Mac shelf for collecting and moving files, links, text, and images. Its [FAQ](https://dropoverapp.com/faq) describes a one-time Pro purchase. | Dragging material into and out of a shelf is a proven utility pattern. Give it a durable AI reuse workflow. |
| [ArtifactKeep](https://artifactkeep.com/) and its [guide](https://artifactkeep.com/user-guide) | Local libraries for prompts, generated-image metadata, conversation files, and model references; portable exports. | Linking AI material and storing generation details are existing capabilities, not an unclaimed category. |
| [Image MetaHub](https://github.com/LuqP2/Image-MetaHub) | A local generative-media library with metadata search and other advanced organizing features. | Avoid competing first on exhaustive model formats or managing enormous output folders. |
| [Msty](https://msty.ai/pricing/) | A broad AI workspace; free core and a $349 lifetime paid option among its plans. | A complete multi-model workspace is a substantially broader product. Keep this app focused. |
| [Claude Projects](https://support.anthropic.com/en/articles/9517075-what-are-projects) and [memory import/export](https://support.claude.com/en/articles/12123587-import-and-export-your-memory-from-claude) | Native project context and memory portability already exist within an AI provider's product. | Do not position basic memory import as the reason this app must exist. Emphasize selecting and reusing working material across applications. |

A [public user discussion](https://www.reddit.com/r/PromptEngineering/comments/1nhg1ou/tired_of_copy_pasting_prompts_rant/) describes repeatedly pasting project primers across AI services, and difficulty trimming an oversized primer for a new task. This is useful qualitative evidence for a workflow problem. It does not establish its prevalence, willingness to pay, or retention. Some replies and other discussions promote their own products, so they should not be counted as independent demand evidence.

[Anthropic's context-engineering article](https://www.anthropic.com/research/effective-context-engineering-for-ai-agents) argues for carefully selecting relevant material within limited context. This is useful background for optional future context packing; it does not add a composer to the five-feature release. This supports a design principle; it does not prove that the proposed app will improve answers.

## Audience and product hypothesis

Starting audience: independent designers, builders and writers moving between an AI chat and actual work. They repeatedly retrieve the same instructions, adapt a familiar prompt, attach references and track a next question. Using multiple AI services is not a prerequisite.

Job: keep a small reusable kit within reach without opening a full notes application or another AI service. Validate less searching and window switching, not promised improvements in AI output.

The supplied PRD also cites [Resurf](https://resurf.so/), [Scopeful](https://www.scopeful.org/) and [Master Canvas](https://github.com/wassermanproductions/master-canvas). Those comparisons are attributed to the brief; their current capabilities were not independently rechecked during this documentation update.

**Critical assessment:** storage alone and removing AI APIs do not create a moat. The app has to beat Notes, folders and existing utilities on retrieving and reusing actual work. The edge-access kit is a product hypothesis to validate.

## First-release features

### 1. Instructions on tap

Save labelled text cards, pin favourites, search and copy reviewed text with a named Copy button. Examples: writing style, project constraints and review checklist. Selecting a title previews/edits rather than copies. Preserve Unicode and line breaks, with only documented line-ending normalisation. Feedback confirms clipboard completion, never delivery. Empty cards cannot be saved.

### 2. Fill-in prompts

Write explicit named fields such as `{{audience}}`, fill them, inspect complete text and copy. Repeated names share a value. No model rewrites or optimises the request. Malformed syntax blocks template saving; incomplete fields block copying. Values remain literal text and are not parsed again. Filled drafts remain separate from saved templates. The [local specification](nivlet-product-requirements.md#03--first-release-features) records grammar and reset behavior.

### 3. Reference shelf

Import screenshots/images and other files with a label and note through a picker, Finder drag or explicit paste. Preview supported files or drag an app-owned copy of original bytes out. Removing the source from Downloads must not break a reference. Notes never modify the original file. Copy note and Drag file are separate actions. Provide Finder/manual attachment fallback; compatibility belongs to the receiving app. No image understanding, OCR, automatic URL fetching or upload.

### 4. Project pockets

Each pocket owns instructions, templates, references and one scratchpad. Switching changes the local kit, not the active AI conversation or provider memory. Search defaults to the pocket's labels, instruction/template bodies and reference notes; All pockets is explicit. Hidden file contents are not indexed. Flush edits on switching and restore view state. No live cross-pocket links or nested hierarchy is required in v1.

### 5. Scratchpad

One autosaved plain-text note/checklist per pocket for next questions and small tasks. Explicit paste only; no clipboard or chat-history recording. Show save status and persistent failures. Keep temporary notes distinct from reusable instructions.

## Essential shell and ownership behavior

These enable the five tools rather than adding product modes:

- Click-to-open left/right edge tab, menu-bar access and an optional configurable shortcut.
- Pin-open mode, predictable Escape/click-away and no lost text or stolen outside clicks.
- Display recovery, keyboard/VoiceOver access, light/dark appearance and reduced motion.
- Preview/editor inside the panel; no mandatory brief-building funnel.
- Local metadata and app-owned original files, without a working-feature server dependency.
- Portable pocket/all-pocket export and restore, including attachments.
- Undo, recoverable pocket deletion, safe saves and migration snapshots.

The brief proposes dimensions, display rules and shortcut defaults, which require testing. Full-screen overlays, Spaces and Stage Manager need a native feasibility check; universal overlay support is not promised.

## Representative session

1. Open the edge tab while working in an existing AI application.
2. Choose the Website pocket and copy its writing-rules card.
3. Fill a page-critique template, inspect the complete text and copy.
4. Preview a layout reference and drag its original file to the chat if needed.
5. Record “check mobile layout next” in the scratchpad.
6. Tuck the panel away and continue in the existing application.

The user chooses every transfer. No context composer, automatic submission or linked-outcome workflow is required.

## Outside the first release

The brief identifies context packing, answer comparison/text diff and clean-paste formatting as optional follow-ons, not commitments. Add one only after observed use supports it.

Also excluded: required Use / Keep / Avoid workflow, brief-building funnel, linked input/output setups, AI generation/rewriting, semantic search, OCR, generation-metadata import, MCP/CLI agents, browser extensions, automatic conversation reading, auto-paste/send, sync, collaboration, voice and free-form canvas.

The original research's wider feature menu is not a roadmap. OCR and floating secondary reference windows are not launch requirements, and no next-release commitment is made here.

## One-time purchase economics and open choices

The supplied brief proposes US$2 within US$1–3. At that price, fixed transaction fees, refunds, support and distribution costs require specific validation. No merchant is selected. Verify Indian seller onboarding/payouts, buyer countries/currencies, taxes and fee structure before choosing one. This documentation update has not verified those commercial details.

Do not silently substitute a higher price or subscription if economics fail; raise that decision explicitly.

Proposed licence: one person, two personal Macs, signed entitlement verified locally without periodic renewal. Proposed trial: non-expiring, one pocket, 10 instructions/templates combined, 10 references and full scratchpad/copy/drag. Price, trial limits, seats and future-upgrade policy remain owner decisions.

Paid base features should continue offline. Perpetual base-app use is distinct from every future upgrade, indefinite support and compatibility with every future OS. Direct distribution still requires signing, notarization, installer testing and a recovery policy.

## Validation and implementation gates

The supplied brief proposes eight target users with non-sensitive work: six complete the core flow unaided, five return on three separate days in a week and four choose a disclosed US$1–3 purchase when checkout exists. These are proposed thresholds, not results. Measure manually with consent; no silent analytics. No outreach has been performed.

These five gates come from the brief. [The build phases](phases.md) split them into eight implementation phases.

1. Native feasibility: focus, edge target, display recovery, pin and file handoff.
2. One-pocket vertical slice covering the five tools and safe persistence.
3. Search, multiple pockets, accessibility, recovery and backup/restore.
4. Observed reuse, payment economics, offline entitlement and licence recovery.
5. Website release with real footage and a tested compatibility list after open decisions are resolved.

The [local requirements](nivlet-product-requirements.md) provide detailed behavior, release-blocking checks and open decisions. This update creates documentation only; it does not implement or publish an app.
