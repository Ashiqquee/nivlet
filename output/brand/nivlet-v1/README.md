# Nivlet — Folded shelf identity

Created 30 October 2026 for the native Mac utility. This is an identity proposal for owner review. The spelling follows the repository's selected name, **Nivlet**.

## Direction

A folded N suggests tucking reusable material into a small shelf or project pocket. Broad forms, eased outer corners and a diagonal opening give the mark its character. The name uses a clean, substantial sans-serif treatment. The identity uses charcoal and white so it can sit beside the app's existing tool accent hues.

The artwork was generated with the built-in image_gen tool, using the original generated mark as the reference for subsequent assets. Each is a raster PNG; these are not editable vector masters. Minor geometry and pixel-color differences between generated variants remain. The typography is generated artwork, not an identified or bundled font. [Exact prompt set](PROMPTS.md).

## Research and references

Inspected public sources on 30 October 2026:

| Reference | Evidence and takeaway |
| --- | --- |
| [Pinterest: Modern and Minimal tech startup](https://www.pinterest.com/pin/439171401182766528/) | Opened the public pin and visually inspected its Ctrl/Alt design and related identity thumbnails in an isolated browser session. The pin credits Ferdous Hasan and links to Dribbble. It uses simple geometry and monochrome/color variants. Treat it as visual inspiration, not an established company's brand manual. |
| [Raycast press kit](https://www.raycast.com/press) | Official guidance separates the symbol, name lockup and app icon, provides light/dark variants and favors dark backgrounds. Inspected the page and repository capture `references/ui-ux/2026-best-apps/raycast-home.png`. Adopt the flexible asset system and confident small symbol, not Raycast's shape or red. |
| [Resend brand kit](https://resend.com/brand) | Official kit provides black and white wordmarks and icons, emphasizes the wordmark for recognition, and specifies consistent name casing. Adopt consistent spelling and useful standalone assets. |
| [Raycast on YC](https://www.ycombinator.com/companies/raycast), [Resend on YC](https://www.ycombinator.com/companies/resend) | Confirmed that these examples are YC companies. They are examples, not evidence that all YC companies follow a single design style. |

The shared pattern is our design interpretation: one memorable symbol, readable lettering, a restrained palette and separate assets for small contexts. No reference artwork is included in this delivery.

## Files

| Asset | Dimensions / use |
| --- | --- |
| [Preview](preview.html) | Open locally to compare the logo variants and icons at their displayed sizes. |
| [Standalone N](nivlet-mark-master.png) | 1254 × 1254, dark mark with transparency; use on light surfaces. |
| [Logo with name](nivlet-logo-dark.png) | 2172 × 724, dark artwork with transparency; use on light surfaces. |
| [Reverse logo](nivlet-logo-on-charcoal.png) | 2172 × 724, white artwork on an opaque charcoal background. This is not a transparent white logo. |
| [Favicon master](favicon-master.png) | 1254 × 1254, white N on an opaque charcoal square. |
| [favicon.ico](favicon.ico) | PNG-compressed 16, 32 and 48 px frames. |
| [16 px](favicon-16.png), [32 px](favicon-32.png), [48 px](favicon-48.png) | Browser favicon PNGs. |
| [Apple touch icon](apple-touch-icon.png) | 180 × 180, opaque. |
| [192 px](icon-192.png), [512 px](icon-512.png) | Larger square browser icons; not a macOS app icon set or maskable icon. |
| [ICO packaging script](package-favicon.swift) | Rebuilds the ICO container from the existing small PNGs and verifies all frames with ImageIO. |

Suggested website integration after copying the assets into the website's public directory:

```html
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
```

Keep the name lockup for introductions and website navigation; use the symbol alone for browser tabs. Preserve the aspect ratio and existing clearspace. Avoid rendering the full wordmark at favicon sizes. The square favicon's background helps it remain visible in both light and dark browser chrome.

## Verification

Environment: macOS 26.6.2 (25G83), Apple Swift 6.4, macOS 27.0 SDK, Apple `sips` and ImageIO. No dependencies installed. The client date for this record is 30 October 2026.

- Visually inspected the generated primary mark, six-letter Nivlet wordmark, reverse logo and favicon master.
- Inspected exported PNGs at 16, 32 and 48 px. The N remains recognizable; fine interior separation softens at 16 px.
- Verified dimensions and alpha metadata with `sips`. The primary mark and primary logo have alpha; favicon assets and the reverse logo are opaque.
- Packaged the existing PNGs without redrawing them. ImageIO decoded all three ICO frames and verified their dimensions.
- Rejected the initial white transparent reverse attempt because of visible edge/alpha artifacts. It is excluded from the bundle; the delivered reverse logo has a charcoal background.

No app source, Xcode asset catalog, menu-bar symbol or live website was changed. The IDE's `website/` path is absent from this checkout. Native app-icon integration, Safari/Firefox favicon behavior, an editable SVG master, exact one-color prepress output and trademark clearance have not been verified. No native feature tests were needed for these separate artwork files.
