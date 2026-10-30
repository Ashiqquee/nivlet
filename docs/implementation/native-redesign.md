# Native welcome and shelf refinement

30 October 2026 · Owner-requested refinement within [Phase 6](phase6-beta.md).

The owner rejected the initial text-heavy welcome. First run now shows an original miniature shelf, one short introduction, **Try a sample pocket** and **Start blank**. The optional Quick guide holds instructions and keyboard help. The everyday shelf has a smaller header, quieter search scope, natural-case section labels, simpler blank counts and useful empty states. Existing persistence, exact copy and panel behavior remain the contracts being verified.

## Design evidence and scope

Inspected the supplied rejection screenshot, existing Refbox shelf/adjacent preview captures and actual first-party [Raycast, Things and Screen Studio images](../../references/ui-ux/native-redesign-2026-10-30/README.md). Borrowed hierarchy, density and surface restraint; no third-party artwork ships. This review covers the changed native SwiftUI welcome/guide/error and prompt shelf, using AppKit panel/focus bridges, system typography, SF Symbols and `ShelfStyle`. It does not audit the marketing site or certify every app state.

Followed `AGENTS.md`, the product requirements, architecture, Phase 6 deliverables, native UI guide and the macOS, Apple HIG, SwiftUI and six `better-*` domain skills.

| Domain | Evidence inspected | Result |
|---|---|---|
| Accessibility | Native AX labels/headings, hidden decorative scene, guide Escape regression, exact keyboard flow, 200% welcome/error at 320 × 360 | Changed states checked; spoken VoiceOver and complete traversal remain unverified |
| Layout | Ordinary/compact welcome, fixed action area, optional guide, error and empty shelf captures | Initial instruction wall and enlarged-layout crowding addressed |
| Writing | Welcome, guide, empty and retry copy | Shorter action-led text; honest copy/attachment and local privacy language retained |
| Typography | System 13 pt body, 14 pt titles, 17 pt headings, 26 pt welcome title; 100–200% scaling | Compact welcome uses a shorter 17 pt heading; actual content still scales |
| Color | Semantic ink on sampled native light/dark canvases and token surfaces | Tertiary opacity raised to 0.66; measured text pairs exceed 4.5:1 |
| UI | Original scene, existing rail/materials, smaller header, search scope, section rows and empty state | Consistent with the approved launcher-style system |

## Findings addressed

| Severity | Domain | Location | Before | After | Why |
|---|---|---|---|---|---|
| HIGH | Layout | `Nivlet/Features/Panel/QuickStartView.swift:12` | Instructions and settings occupied the starting screen; enlarged content competed with actions | Visual welcome, optional guide, bounded scrolling and persistent starting choices | The first useful action needs to be discoverable and reachable |
| HIGH | Color | `Nivlet/Features/Panel/ShelfStyle.swift:26` | Low-opacity tertiary label ink failed the sampled normal-text contrast threshold | Semantic label opacity 0.66 | Small supporting content must remain readable |
| MEDIUM | Typography | `Nivlet/Features/Panel/PanelTypography.swift:18` | Titles/section labels competed with body content | Explicit heading/title roles and medium natural-case groups | Clear hierarchy supports scanning |
| MEDIUM | Layout | `Nivlet/Features/Panel/PanelRootView.swift:260` | Long search-scope text occupied the search field; empty footer consumed space | Accessible scope icon; empty lists omit the unused footer | A narrow panel needs room for the user's content |
| MEDIUM | UI | `Nivlet/Features/Panel/TextShelfView.swift:65` | Several small metadata chips and inline controls crowded enlarged rows | One blank-count line; inline controls limited to ordinary text at sufficient width | Preserve readable prompt titles and clear action grouping |
| MEDIUM | Writing | `Nivlet/Features/Panel/QuickStartView.swift:158` | Saving errors could sit alongside a long introduction | Dedicated persistent error with direct retry and shorter recovery copy | Recovery needs to explain the next step without losing the action |

## Actual native captures

These are isolated native app window captures with synthetic content, not browser mockups. Retina images have twice the listed point dimensions. Some shelf captures include the inward rail in their image bounds.

| State | Frame in points | Capture |
|---|---|---|
| Welcome, dark / light, 100% | 420 × 640 | [Dark](native-redesign/welcome-dark.png), [Light](native-redesign/welcome-light.png) |
| Quick guide, dark, 100% | 420 × 640 | [Guide](native-redesign/guide-dark.png) |
| Compact welcome, dark, 100% | 320 × 360 | [Welcome](native-redesign/welcome-320x360-dark.png) |
| Compact welcome, light, 200% | 320 × 360 | [Enlarged welcome](native-redesign/welcome-200-320x360-light.png) |
| Real save failure, light, 200% | 320 × 360 | [Recovery](native-redesign/error-200-320x360-light.png) |
| Blank prompt shelf, dark, 100% | 320 × 360 | [Empty shelf](native-redesign/empty-320x360-dark.png) |
| Sample prompt shelf, dark, 100% | 420 × 640 | [Shelf](native-redesign/shelf-dark.png) |

## Verification

Apple M3 MacBook Air, arm64, built-in Retina display, macOS 26.6.2 (25G83), Xcode 27.1 (27A9275), macOS 27 SDK, Swift 6.4 / language mode 6. Deployment floor stays macOS 14.

- Full `xcodebuild test` passed: **122 tests / 210 cases**, zero failures, skips or runtime warnings. New guide navigation regression verifies that Escape returns to welcome before completing the introduction. [Content-free result](native-redesign/verification.json). Result bundle: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.30_16-29-33-+0530.xcresult`. Only existing no-AppIntents-dependency metadata notices appeared.
- Native keyboard check passed: Cmd-F search, query Escape, Cmd-N title focus, Tab into native editor, Cmd-S, Return preview, Cmd-Return exact private copy including Unicode/newline/trailing spaces, scratchpad to-do creation and root Escape/reopen. [Observed checks](native-redesign/keyboard.txt).
- First-run sample creates and selects its ordinary separate pocket; exact reviewed Writing style text copied privately. Start blank opens the empty prompt shelf. Quick guide/Back navigation was exercised through native AX controls.
- Real failed save: temporarily removed write permissions from only the disposable review library directory and `library.sqlite*`, pressed Try sample, inspected the persistent error at 200% / 320 × 360, restored exact original permissions in `finally`, then pressed Retry. It saved the existing sample identity. [Failure checks](native-redesign/save-failure.txt), [retry](native-redesign/save-retry.txt). No working pocket or general clipboard was used.
- [Contrast calculation](native-redesign/contrast.json) resolves actual sRGB semantic colors and samples the native canvases. Minimum primary/secondary/tertiary contrast is 12.43/5.52/4.62 in light and 8.85/5.45/4.86 in dark across canvas, raised, selected and keycap pairs. Opaque focus outline minima are 3.91 and 4.51. This is a token-pair calculation, not certification of every pixel, accent, material or control state.

Early automation attempts lost foreground/window state or used an incomplete menu label; these were not counted as passes. Final captures assert actual CG window bounds after each state change because AX resizing does not persist a live user resize. The keyboard flow was repeated successfully with explicit foreground guards.

**Not verified:** spoken VoiceOver; every control by Tab/Shift-Tab and Full Keyboard Access; all intermediate text sizes and long-label states; actual Increase Contrast/Reduce Transparency/Reduce Motion system combinations; external file destinations; Spaces/fullscreen/Stage Manager; physical display/wake configurations; other macOS runtimes and Intel hardware. Existing Phase 6 acceptance gaps remain open. The static welcome illustration adds no animation or newer OS requirement.

## Reproduce

Use the full Xcode installation for native builds. The checker targets only `ashique.nivlet.redesignreview` and the private `nivlet-verification-redesign` pasteboard.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/nivlet-redesign-native \
  PRODUCT_BUNDLE_IDENTIFIER=ashique.nivlet.redesignreview PRODUCT_NAME=NivletRedesignReview build

xcrun swiftc scripts/verify_native_redesign.swift -o /tmp/nivlet-redesign-verify
open -n /tmp/nivlet-redesign-native/Build/Products/Debug/NivletRedesignReview.app --args \
  -NivletVerificationLibrary redesign-fresh-review \
  -NivletVerificationPasteboard nivlet-verification-redesign \
  -NivletOpenOnLaunch YES -NivletAppearance dark -NivletTool prompts \
  -shell.introductionCompleted NO -shell.fullHeight NO -shell.panelHeight 640 \
  -shell.textSize standard
/tmp/nivlet-redesign-verify sample
/tmp/nivlet-redesign-verify keyboard
/tmp/nivlet-redesign-verify quit

./scripts/build_internal_beta.sh
```

Choose a fresh fixture suffix for a blank first run. Normal existing libraries skip automatic onboarding. Capture/guide/back/blank/resize/failure/retry stages are also available; failure requires a deliberately unwritable **disposable** library, never the working root. The local arm64 ZIP is ad-hoc signed, with no upload or notarization.

## Verdict

**Approve for the inspected visual changes:** no known HIGH finding remains in the captured welcome, guide, recovery and shelf states. This scoped review does not pass the complete Phase 6 native accessibility/compatibility gate.
