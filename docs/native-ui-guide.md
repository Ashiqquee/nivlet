# Nivlet — native Mac UI guide for agents

[Requirements](nivlet-product-requirements.md) · [Architecture](architecture.md) · [Reference screenshots](../references/ui-ux/refbox/README.md) · [Skills](agent-skills.md)

## Design direction

A quiet native utility stays beside the user's real work. Borrow the Refbox demo's small desktop footprint, strong content/preview relationship, consistent spacing and restrained controls. Translate those ideas into readable prompt rows and forms; a column of large image thumbnails is not suitable for every tool.

**Owner-directed visual system (27 October 2026):** a launcher-style surface modelled on the best-designed apps of the past year — see the [research](../references/ui-ux/2026-best-apps/README.md) and [redesign record](implementation/ui-redesign.md). Keep: translucent dark-first material with opaque fallbacks, one accent hue per tool (tiles, glow, progress — never body text), one highlighted row with inline actions, the footer action bar (status · primary `↵` · `Actions ⌘K`), the ⌘K action panel driven by `ShelfCommands`, HUD copy toast, and inverted-ink primary buttons. Shared tokens and components live in `Nivlet/Features/Panel/ShelfStyle.swift`. Don't revert to stock grey cards without an owner decision.

The captured page is a promotional website. Its headline, pricing sections, large typography, purple wallpaper and embedded artwork are not the application's design system.

## Before changing a surface

Read the requested phase and inspect the relevant screenshot with an image viewer. State which actual capture informed the change. Compare to the product's five-tool scope. For native behavior, read `macos-design-guidelines` and the relevant macOS references from `swiftui-expert-skill`. Check current rules in the matching `apple-hig` reference: `panels`, `windows`, `the-menu-bar`, `menus`, `drag-and-drop`, `focus-and-selection` or `materials`. It reflects macOS 27; the older skill does not.

Use the existing `better-*` owner for focused improvements. Read only needed supporting files. A complete interface audit may use `better-interface`; ordinary feature work does not need a ritual full audit or unrelated redesign.

## Surface contracts

| Surface | Intent |
|---|---|
| Edge tab | Inward chevron, deliberate click, generous invisible hit target, adjustable position; never hover-open |
| Panel header | Pocket switcher, clear search scope, Pin and collapse; avoid an unexplained wall of icons |
| Prompts | One list for prompts, rules and context (instructions merged 27 Oct 2026). Plain prompts copy directly; prompts with named blanks show inputs and complete rendered text, and missing inputs prevent copying |
| References | Content thumbnails or file-type fallbacks, note, preview and separate Drag file/Copy note actions |
| Notes | Immediate plain-text/checklist editing with honest save status |
| Inspector | Preview/edit inside the existing panel; Escape backs out before tucking |
| Error/empty state | Explain what happened and offer an appropriate recovery/create action |

Use the PRD's proposed panel dimensions as starting values, not a reason to clip content. Long labels, prompts, filenames, keyboard focus and enlarged text need meaningful wrapping, scrolling or a full-value preview.

## Native appearance and behavior

- Prefer system font/text styles, semantic platform colors and native materials with readable opaque fallbacks.
- Follow light/dark, increased contrast, reduced transparency and reduced motion. Newer visual APIs require availability checks; Liquid Glass is not a default requirement.
- Prefer SF Symbols with clear accessible action labels. Tooltips supplement rather than replace visible discovery/keyboard access.
- Use coherent spacing and nested radii; keep density appropriate to a small text-heavy utility.
- Apply transient feedback for successful Copy. Save failures persist with a recovery path; they are not disappearing success toasts.
- Respect normal text selection, editing shortcuts, undo and first-responder behavior. No global shortcut is enabled silently.
- Native AppKit/SwiftUI accessibility is the implementation surface. Browser advice about ARIA, CSS breakpoints or hover media queries is conceptual guidance only.

This app is a single-purpose edge panel. Community rules meant for document windows do not require extra windows, permanent sidebars, custom traffic lights, unrestricted panel growth, fullscreen promises, a Dock icon or new integrations. Apply the useful desktop principle in the context of this product.

## Evidence required

Compare actual app screenshots to the relevant reference while preserving original product content. Inspect normal, narrow/enlarged-text, empty, error and keyboard-focused states that the change affects. Check actual behavior for focus, pin/tuck and drag; a still screenshot cannot prove them.

Record tested vs untested displays/OS versions and accessibility checks. The Refbox captures prove what its public demo displayed at capture time, not how an installed app handles Spaces, permissions or persistence.
