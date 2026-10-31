# Website refinement — Raycast structure, Nivlet palette, Geist

31 October 2026 · Local review, not publication or final owner acceptance.

**Superseded on the same day by a full home-page rebuild.** At the owner's request (“change our website completely”, matching Raycast’s hero animation and type), the home page now uses self-hosted Inter, CSS-drawn animated amber beams with pointer parallax, staggered hero entrances and scroll reveals. It also has an auto-advancing native-panel tour with a pause control, animated keycaps for ⌘F/↩/⌘K/Esc, an animated tool carousel, privacy cards, the inline walkthrough, FAQ, coffee support and a closing beam call to action. No Raycast artwork, code or brand assets are copied, and the native screenshots and recording are unchanged. Verified: `tsc`, `next build` and `npm run verify` (9 HTML files, 318 references, 6 media and 16 design hashes). Browser checks at 1440 and 390 px showed no horizontal overflow. Under reduced motion, no animations ran and all content stayed visible. **Not verified:** screen reader, full keyboard pass or 200% zoom. The sections below describe the earlier Geist iteration.

**Owner copy decision, 31 October 2026:** the owner asked for the privacy, terms, support, compatibility and release pages to read as final, with no draft or review notices. They now use dated, approved-style wording, the walkthrough transcript link is removed (captions remain), and the release page still states that no download is available yet. The terms include standard “as is” and liability wording written for this site. It has not been reviewed by a lawyer.

The owner selected `references/ui-ux/marketing-sites/raycast-full.png`, requested Nivlet’s existing logo assets, then specified a different color palette, Geist, a sticky navbar and removal of generic AI marketing copy. These instructions supersede the earlier white website captures and type experiments. The current site remains Next.js / TypeScript / Tailwind.

## Research applied

- [NN/g: Aesthetic and minimalist design](https://www.nngroup.com/articles/aesthetic-minimalist-design/): remove low-value information that competes with the actual task, while retaining necessary controls and context.
- [NN/g: Visual hierarchy](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/): use scale, contrast and grouping to keep the product and main actions ahead of supporting detail.
- [ScoreMySite: AI design slop](https://www.scoremysite.dev/mistakes/ai-design-slop): practical examples of interchangeable stock copy, repeated cards and unrelated decoration. This is the author’s design guidance, not an independently established benchmark for Nivlet.

Our application: remove eyebrow slogans and the redundant six-icon workflow section; give tools their actual names; keep native screenshots and a deliberate recording central; use one action style and a coherent icon set. The amber backdrop is a single decorative asset following the owner’s visual reference, not a substitute for product evidence. Tool hues distinguish native categories.

## Scope and findings addressed

| Domain | Before | Current result |
|---|---|---|
| Typography | Rejected system/Instrument/Inter choices, italic headline and dense tracking | Owner-selected self-hosted Geist; 600 headline, readable body and consistent hierarchy |
| Writing | “A little space for your work”, all-caps eyebrows and closing slogans | Direct prompt/file/note copy, actual tool names, no home-page eyebrow labels |
| Layout | Fictional tilted brief, repeated workflow blocks and a nonsticky header | Real native screenshot showcase, fewer sections and sticky navigation with anchor clearance |
| Branding | Provisional edge glyph and opaque reverse-logo rectangle | Existing folded-N artwork/favicons; transparent original wordmark rendered white without changing source pixels |
| Icons | Unicode placeholders and unrelated weights | Shared Lucide glyphs and consistent CSS app tiles; deliberate tool colors |
| UI | White/blue draft rejected by owner | Near-black surfaces and original amber/copper artwork, with native blue/green/violet tool accents |

Original brand files under `output/brand/nivlet-v1/` are unchanged. The final amber art and [exact generation/edit prompt set](../../../website/artwork/amber-folds-prompt.md) are retained in the website. The exploratory red asset is not shipped. Native sources, stored data and native screenshots/recording are unchanged.

## Inline walkthrough and support refinement

The owner rejected the recording modal. It has been removed completely. Screenshots and Video now share the product showcase; playback stays inline and starts only after an explicit user action. A 14.7-second edit of the original capture cuts idle time, uses a readable desktop frame and a separate portrait crop below 700 px, and provides chapter buttons, native playback controls, optional descriptions and a transcript. Switching to screenshots unmounts and pauses the video. The original recording is unchanged.

[NN/g’s video usability guidance](https://www.nngroup.com/articles/video-usability/), [Wistia’s player customization guidance](https://support.wistia.com/en/articles/8284255-customize-your-video) and [Screen Studio](https://screen.studio/) informed the duration, controlled playback, chapter access and readable framing. The edit is illustrative, not a performance measurement.

The separate optional support section uses the official Buy Me a Coffee cup and owner-requested informal copy. Footer credit links to ashique.work, with its actual favicon immediately before Ashique. Both assets are stored locally and attributed in provenance; no third-party widget is loaded.

## Verification

Geist loaded from the same origin and the home page had zero eyebrow/slogan labels in the inspected DOM. Desktop sticky navigation stayed at 16 px after scrolling; narrow-screen CSS uses 10 px. Native screenshot switching, recording controls, keyboard focus and final export checks are recorded in [the current verification file](verification.json). Test the production export after framework changes; a successful dev render alone is not release evidence.

The final production export passed build, TypeScript, all 293 local references/anchors, six native media hashes and 15 design asset hashes. Chrome 156 verified 1440/390/320 px layouts without horizontal overflow, desktop/mobile playback, chapter seeking, screenshot switching, loaded support/credit assets and visible keyboard focus. The local preview now supports byte ranges; Python’s original simple server prevented seeking. Four byte-exact range responses and an invalid-range response were checked.

Screenshots: [complete page](website-geist-final.png), [inline desktop video](website-inline-video-desktop.png), [phone video](website-inline-video-390.png), [coffee and footer](website-coffee-footer.png), [320 px footer](website-coffee-320.png).

Spoken screen-reader coverage and complete Safari/Firefox compatibility remain unverified. This scoped refinement does not pass Phase 6/7 native acceptance, signing, user validation or publication gates. Aesthetic owner acceptance remains open until the owner reviews the result.
