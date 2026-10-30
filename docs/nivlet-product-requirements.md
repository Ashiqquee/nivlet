# Nivlet — AI work side panel

Local requirements derived from the supplied PRD v0.3 · updated 29 October 2026

Source: [Original Brief Board product requirements](https://files.instinct.com/ipl7v9gvfnb3-brief-board-product-requirements). All four source sections were read: Product, Experience, Engineering, and Release & sources. This is a local adaptation, not a verbatim export.

Related: [Research and release scope](ai-shelf-product-research.md) · [Architecture](architecture.md) · [Build phases](phases.md) · [UI references](../references/ui-ux/README.md) · [Refbox design reference](https://ref.box/)

Status: native development implementation; Phases 2–5 pass their local gates ([Phase 5 evidence](implementation/phase5-recovery.md)). Distribution and final acceptance checks remain incomplete; no launch. The owner selected Nivlet as the project name on 27 October 2026, replacing the earlier Brief Board working label. Visual identity and domain/brand clearance remain open. Requirements describe intended behavior; measurements and compatibility checks have not been completed. Choices explicitly marked proposed remain open.

## 01 · Product contract

A discreet tab at the edge of the Mac screen opens a compact toolkit beside the user's existing AI application. The kit contains prompts (plain or with fill-in blanks), references and a scratchpad, organised by project pocket. *Owner decision, 27 October 2026: instructions and prompts merged into one Prompts list; standing rules and context are saved as plain prompts.*

- Website download; no App Store for v1.
- No in-app model, provider API, API key, generated prompts or AI subscription. Local tools function offline.
- Click the edge tab to open; Pin keeps the panel visible. Menu-bar and keyboard access are alternatives.
- The four first-release tools are the product; the panel is their shared shell.
- Desired one-time price: US$1–3 for continued base-app use. US$2 before applicable tax is proposed, not final.

“No API” means no model/provider dependency. Checkout, licence delivery and optional signed update checks still need distribution infrastructure. External AI services are separate and may charge their own fees.

## 02 · Audience, job and proof

Audience hypothesis: independent designers, builders and writers moving between an AI chat and actual work. They retrieve standing rules and prompts, adapt familiar templates, attach references and track the next question.

Job: keep a small reusable working kit within reach without switching to a full notes app or another AI service. Validate less searching and window switching, not promised improvements in AI output.

Example: open Website pocket, copy writing rules, fill a page-critique template, inspect a layout reference, drag its original file into the chat, record “check mobile layout next,” and tuck the panel away. Each transfer is chosen by the user.

Proposed validation gate with eight target users and non-sensitive sample work:

- At least six complete open → find → copy/fill/attach → return unaided.
- At least five use the app on three separate days in a week.
- At least four choose a disclosed US$1–3 purchase when real checkout exists.

These are proposed thresholds, not observed results. Measure manually with consent. No silent analytics or tester outreach is authorised merely by this document.

## 03 · First-release features

### Prompts

*Owner decision, 27 October 2026: “Instructions on tap” and “Fill-in prompts” became one Prompts tool. Standing rules and context are plain prompts; named blanks are optional per prompt. Existing instructions migrate to plain prompts.*

Save labelled text cards, pin favourites, search and copy exact reviewed text with one deliberate click. Examples: writing style, project constraints, review checklist and reusable task prompts.

- Fields: label, body, favourite flag, order and an optional “Use named blanks” flag.
- Named Copy button copies; selecting the title opens preview/edit.
- Preserve Unicode, emoji and line breaks, with documented line-ending normalisation only.
- Feedback says “Copied to clipboard,” never implying the text was pasted or sent.
- Empty cards cannot be saved.
- Rename, duplicate, reorder and move between pockets through accessible menus as well as drag.

#### Optional named blanks

A prompt may opt in to explicit named blanks: fill them, inspect complete text, then copy. Without the option, braces are literal text and the prompt copies exactly as saved. No model rewriting or optimisation.

- Grammar: `{{field_name}}`; names begin with a letter and otherwise allow letters, digits and underscore.
- Repeated names share one value and produce one field.
- Highlight malformed tokens and block saving until fixed.
- Escape literal braces individually with a backslash; preview removes the escape. Source `\{\{literal\}\}` renders as `{{literal}}` without creating a field.
- All fields required in v1. No scripts, nested expressions or automatic variables.
- Entered values remain plain text; token-like input is not reparsed.
- Display complete rendered text beside/below inputs. Disable Copy until complete.
- Keep fill values in the current local draft, separate from the template; provide explicit Reset.
- Editing source warns before clearing a filled draft.
- Unit-test grammar, escaping, repeated names, literal values and preview/copy equality before release.

### Reference shelf

Save screenshots/images and other files with a label and note. Preview beside the task or drag original bytes out. No image understanding or automatic upload.

- Import through file picker, Finder drag or explicit paste.
- Images receive bounded thumbnails; other files receive a type icon and native preview where supported.
- Store app-owned copies. Never move or mutate source files.
- Notes do not alter bytes. Copy note and Drag file are distinct actions.
- No remote-link fetching for preview, active HTML execution or implicit attachment.
- Receiving applications determine compatibility. Provide Reveal in Finder/manual attachment and remind users to check upload completion.

### Project pockets

Each pocket owns prompts, references and notes. Switching changes the local kit, not the active AI conversation or provider memory.

- Search active-pocket labels, prompt text and reference notes; not hidden file contents.
- Provide explicit All pockets scope.
- Flush saves on switching; restore the last view and position where possible.
- One pocket owns each item; no live cross-pocket links in v1.
- Duplication creates independent metadata; immutable asset bytes may be shared internally.

### Scratchpad

One autosaved plain-text note/checklist per pocket for next questions and small tasks. Explicit paste only; no clipboard or chat-history recording.

- Plain text plus simple checklist rows; no rich-text renderer required.
- Keep temporary thoughts distinct from reusable prompts.
- Visible autosave status and persistent failures; never show Saved after a failed write.

## 04 · Positioning and scope limits

The hypothesis is a small, polished edge-access kit. Storage alone and removing AI APIs are not a moat. Compare actual reuse against Notes, folders and existing tools.

The [research document](ai-shelf-product-research.md#what-the-research-establishes) contains initial competitor evidence and its limits. The supplied brief additionally cites Resurf, Scopeful and Master Canvas; those descriptions are source-attributed, not independently reverified here.

Outside v1: required Use / Keep / Avoid workflow, brief-building funnel, linked input/output setups, context packer, answer comparison/text diff, clean-paste formatting, AI generation, semantic search, OCR, MCP/CLI agents, browser extensions, automatic chat reading, auto-paste/send, sync, collaboration, voice and free-form canvas. These exclusions do not commit a later roadmap.

## 05 · Visual and interaction reference

Reference: [Refbox](https://ref.box/) and conversation screenshots showing a compact shelf and adjacent reference preview. Its public site describes auto-layout and sections. Installed-app behavior is untested. The edge opener is this product's proposed interaction, not a verified current Refbox feature.

Use native system typography/materials, neutral panels, fine separators, content-led thumbnails and one muted selection accent. Follow system light/dark appearance. Borrow compactness and care; do not reuse branding, logo, artwork or exact layout.

Cards, Prompts, References and Notes are local views. Make text readable in compact rows/cards rather than forcing everything into image-sized tiles. Preview/edit through an in-panel inspector; no hover-only controls.

## 06 · Shell, screens and focus

### First run

Explain that local tools sit beside the AI app and do not read chats or send material. Offer removable sample or blank pocket. Explain open, tuck and pin; offer left/right placement. No compulsory account, permissions wall or conflicting global shortcut.

### Proposed geometry and access

- Default right edge, vertically centred on primary display; inward chevron mirrored on left.
- Visible tab: 14 × 48 points; hit target: 28 × 64 points.
- Click opens; hover never opens.
- Vertical drag with preview/snap; exact edge/display placement in Settings.
- Avoid menu bar, Dock and corners. Tab can be disabled while retaining menu-bar/shortcut access.
- Expanded size: 380 × 640 points; width 320–600 points, height clamped to usable display bounds.
- Remember width, pocket, view and scroll per display where possible.

Dimensions and defaults are proposals to test, not shipping guarantees.

### Dismissal and pin

- Unpinned click-away safely commits edits and tucks without intercepting the other app's click.
- Escape closes the current child menu/editor first, then tucks. Collapse always available.
- Pinned stays above ordinary windows until collapsed/unpinned.
- Editing deliberately takes focus. Opening must not type into another app.
- Returning focus after copy is optional and must prove predictable in testing. No synthetic keystrokes or auto-paste.
- Preserve recoverable drafts/errors if saving fails during dismissal.

### Displays, Spaces and full screen

- One panel and one active tab; no per-monitor duplicates.
- Select display in Settings. Shortcut opens on pointer display when possible.
- Unplugging moves/clamps to primary display; reconnecting creates no duplicates.
- Re-clamp on wake, resolution and display changes.
- Proposed default: current Space only.
- Full-screen overlays, Stage Manager and multi-Space behavior require a native spike. If reliable overlay is unavailable, record limits and provide menu-bar access to a normal desktop panel.

## 07 · Recovery, keyboard and accessibility

- Visible autosave status and persistent save errors.
- Disk-full/interrupted writes retain the last good version; recover unsaved text where safe.
- Single deletion offers Undo. Pocket deletion confirms and uses seven-day recoverable trash.
- Tab/Shift-Tab reaches actions; Command-F searches, Command-N creates in current view, Command-Z undoes, Escape backs out one level.
- Proposed global shortcut: Option-Space, disabled until enabled and conflict-checked. Review note (26 October 2026): Option-Space is the ChatGPT Mac app's default pop-up shortcut, and it types a non-breaking space in ordinary text fields. Both collide with this audience's main workflow, so pick and test an alternative default before Phase 6.
- VoiceOver names include pocket, item type and action.
- At least 13-point text, visible focus, sufficient contrast and no colour-only status.
- Proposed slide: 120–180 ms; no animation with reduced motion.

## 08 · Local implementation proposal

Proposed: SwiftUI with AppKit bridges for NSPanel, screen geometry, menu bar, file URLs/promises, Quick Look and shortcuts. SQLite metadata plus immutable app-owned assets. Proposed macOS floor: 14. Universal binary only after Apple silicon and Intel pass testing. These are engineering defaults, not final owner decisions.

| Entity | Intended data |
|---|---|
| Pocket | UUID, name, order, active view, timestamps, schema version |
| Prompt | UUID, pocket ID, label, source, favourite, order, uses-blanks flag; ordered unique fields when blanks are on; filled draft separate (instructions merged here 27 Oct 2026) |
| Reference | UUID, pocket ID, label, note, asset ID, order |
| Asset | Original name, detected type, size, digest, internal relative path, thumbnail |
| Scratchpad | Pocket ID, plain text, ordered checklist items, revision |
| Preferences | Edge, display ID, vertical position, size, shortcut, appearance |
| Recovery | Journal, trash, migration snapshots; licence state separate from working data |

No provider tokens, chat transcripts or inferred personal profile.

Import/save requirements:

- Stage, hash and copy before confirming success; deduplicate by digest, not filename.
- Commit metadata transactionally; source files remain untouched.
- Debounce typing by at most 500 ms; flush on focus/pocket change, tuck and quit.
- Snapshot before schema migrations.
- Per-file import results; retry failed files only.
- Reject folders. Do not recursively import, execute scripts, expand arbitrary archives, fetch URL previews or monitor clipboard contents.
- Bound thumbnail/preview decoding and keep heavy work off the main thread.
- Provisional file limits implemented in Phase 3: warn above 100 MB, confirm above 500 MB, refuse above 2 GB (decimal bytes). Numeric/scaled-fixture boundaries pass; maximum-size throughput and final values still depend on testing.

## 09 · Copy, file integrity, ownership and privacy

Copy exact reviewed prompt text, with documented line-ending normalisation only. No appended marketing, invisible instructions or file paths.

File drag exposes app-owned original bytes with the original display name. Multi-select shows count/names first. If drag fails, Reveal in Finder exposes an export directory for manual attachment. Never claim an AI received or understood a file. Notes are not silently embedded in images.

Manual import/copy should not require Accessibility, Screen Recording or Full Disk Access. Do not request unrelated permissions.

Since macOS 15.4, Apple has been introducing a pasteboard privacy alert for apps that read the general pasteboard programmatically. Reads that come from a system-recognised paste action, such as Edit ▸ Paste or Command-V, are exempt. Route explicit paste through that standard path, not a custom button that reads the pasteboard, and use the `detect` APIs to enable paste controls without reading contents. Verify on the shipping macOS release; writing for Copy is unaffected.

Export/restore:

- User-triggered export of one/all pockets: versioned JSON and original assets.
- Preview contents and disclose that exports may contain private material.
- Validate schema, digests, paths and total size. Block traversal, symlink escapes and archive bombs.
- Preview restore counts; import as new pockets rather than silently merge.
- Collect assets only when no live item, trash or pending export references them.

Privacy:

- No default analytics, crash upload, required account or cloud backup.
- No background chat/clipboard reading, remote content execution or automatic disclosure.
- Update checks and checkout/licence recovery must not transmit pocket content, names or paths.
- Logs redact content; user-initiated diagnostic sharing includes preview.
- Users choose what to paste/attach to external services.

## 10 · Release-blocking acceptance checks

These are implementation checks to perform, not completed tests.

| ID | Required evidence |
|---|---|
| AC-01 Shell | Mouse/keyboard open/tuck/pin, edit then click-away, Spaces, sleep/wake, display detach. No lost text, swallowed click, stuck invisible window or duplicate tab. Record full-screen limits. |
| AC-02 Plain prompts | Unicode, emoji, long text, braces and line breaks copy correctly; only documented line-ending normalisation. No auto-paste/send. Instructions from older libraries migrate without loss. |
| AC-03 Templates | Repeated fields/escaping correct; incomplete fills/malformed sources blocked; token-like values literal; preview equals copied text; edit/reset warnings preserve saved source. |
| AC-04 Files | Import 20 mixed files, remove sources, restart offline and export. Successful originals match digests. Test current Claude/ChatGPT browser uploads in Safari/Chrome and Mac clients where available; record exact versions/results and Finder fallback. |
| AC-05 Pockets | Two pockets with similar labels: switch/search/duplicate/move/delete/Undo without unexpected crossover. Notes/view state survive immediate quit/restart. |
| AC-06 Recovery | Interrupted/disk-full save preserves last good data. Clean-install restore preserves content. Malicious archives fail without out-of-staging writes. |
| AC-07 Offline entitlement | Import signed paid licence, disconnect, change date/time zone, relaunch. Paid local tools remain usable without server renewal. |
| AC-08 Accessibility | Keyboard/VoiceOver completes flow; light/dark, minimum size, enlarged text and reduced motion work; preview/collapse focus predictable. |

Targets, not measurements: warm open under 150 ms p95, search/copy feedback under 100 ms, 200-item pocket opening within one second and near-zero idle CPU on a documented baseline Mac. Stress-test 1,000 items and interrupted imports.

## 11 · Website, payment and licence

Proposed journey: website demo → exact features/OS limits → trial DMG → signed/notarized install → sample/blank pocket → website purchase → receipt/signed licence → import in app. Browser checkout only. Disclose that no AI service or automatic agent connection is included and provider fees are not bypassed.

US$2 is proposed within US$1–3. Verify Indian seller onboarding/payouts, buyer countries/currencies, taxes, refunds/chargebacks and fixed plus percentage fees before selecting a merchant. Include hosting, support and signing costs. No provider selected. If economics fail, raise the price/model decision explicitly; do not silently add a subscription.

Proposed entitlement: one person, two personal Macs; signed licence verified locally with no periodic server checks. Base features continue without subscription. Future upgrades, eternal OS support and indefinite support are separate promises. Decide abuse, refund revocation and recovery tradeoffs before sale. Test receipt-based recovery with minimal data.

Proposed non-expiring trial: one pocket, 10 prompts, 10 references and full scratchpad/copy/drag. Paid unlock removes limits. Never destroy or lock away existing content if limits change. Trial and seat policy remain open.

## 12 · Distribution and build gates

Developer ID-signed/notarized DMG with stapled ticket; test Gatekeeper on a clean Mac. Website download does not eliminate signing/notarization costs. The supplied brief cites [Apple Developer Program](https://developer.apple.com/programs/) and [Developer ID](https://developer.apple.com/developer-id/); verify local charges and existing membership before budgeting.

Manual signed installer updates suffice for v1. Optional signed updater only after verification. Retain last-known-good releases, migration snapshots and rollback instructions. Failed updates must not disable local paid tools. Do not use disabling Gatekeeper as the normal install path.

| Gate | Deliverable |
|---|---|
| Native feasibility | Edge target, focus/click-away, pin, display/Space recovery, file handoff and signing spike. Record behavior matrix and limits. |
| Vertical slice | One pocket with all five tools; exact copy, byte integrity and safe persistence. |
| Polish | Pocket switching/search, favourites/reorder, backup/restore, Undo/trash, accessibility/appearances. Pass checks and measure performance. |
| Validation/payment | Observe return use; verify low-price economics, recovery/refunds and offline ownership. Outreach needs separate task authorisation. |
| Website release | Resolve owner choices; real footage, supported Macs/tested destinations, privacy/refund/entitlement policy, support route and signed installer. |

No dates or effort estimates promised; estimate after feasibility against actual capacity. Documentation work does not authorise launch, spending, registration or publication.

## 13 · Open decisions and optional follow-ons

Open decisions:

- Visual identity, domain selection and brand clearance for Nivlet.
- Final price/currency, merchant, taxes/refunds, trial, seats and future upgrades.
- macOS floor, Intel support, full-screen/Spaces guarantees after testing.
- Tab dimensions/defaults, shortcut default (Option-Space conflicts; see §07) and conflict handling, and file-size limits.
- Template grammar edge cases: lone `{`/`}`, whitespace inside `{{ name }}`, a backslash before a non-brace character, and a literal backslash immediately before an escaped brace. Settle these in Phase 3 before parser tests are written.
- **Resolved in Phase 2:** preserve reviewed text unchanged, including CRLF, CR and LF; no trimming or Unicode normalisation. See [copy decision and evidence](implementation/phase2-persistence.md#exact-copy-decision).
- Signing membership, support contact, legal/privacy text and tested recovery.

Optional follow-ons, not committed scope:

- Context packer: manually select text/Markdown/code files, preview/exclude private parts and save a labelled bundle.
- Answer comparison: paste two outputs, inspect text differences and let the user judge.
- Clean paste: preview explicit Markdown/list conversions with Undo and no AI rewriting.

Add only when observed use supports it. Keep the panel compact.

## 14 · Sources and limits

- [Supplied full PRD v0.3](https://files.instinct.com/ipl7v9gvfnb3-brief-board-product-requirements): primary basis; public published revision read on 26 October 2026.
- [Refbox](https://ref.box/): public descriptions and conversation screenshots; installed app untested.
- [Research and release scope](ai-shelf-product-research.md): original competitor sources and qualifications.
- [Resurf](https://resurf.so/), [Scopeful](https://www.scopeful.org/), [Master Canvas](https://github.com/wassermanproductions/master-canvas): comparisons cited by the brief, not independently rechecked in this update.
- [Apple Developer Program](https://developer.apple.com/programs/), [Developer ID](https://developer.apple.com/developer-id/): distribution references cited by the brief; local commercial/account details need verification before implementation.

This is an intended-behavior specification, not a working prototype, benchmark report, legal policy, final commercial offer or proof that release gates passed.
