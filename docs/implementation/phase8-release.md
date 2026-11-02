# Phase 8 — local validation and release preparation

Updated 2 November 2026 · **In progress; participant validation and final native acceptance remain open**

**Current public download:** version 0.2 (build 8), published with the owner's authorization on 2 November 2026. The live installer matches the verified local candidate. See [0.2 release evidence](phase8-release/0.2-release.md). It remains ad-hoc signed and not notarized; publication does not complete the remaining release gates.

**Current website:** [Geist/dark-theme refinement](phase8-release/website-refinement.md) supersedes the early white/blue site and its captures below. It follows the owner’s Raycast structure reference with Nivlet’s amber palette, existing logo and sticky navigation.

[Deliverables](../phases/phase8_deliverables.md) · [Website](../../website/README.md) · [Study kit](../validation/README.md) · [Release checklist](../release/checklist.md) · [Review manifest](../release/review-manifest.json)

## Prepared

- A local Next.js App Router / TypeScript / Tailwind website, with a home page and privacy, support/recovery, compatibility, terms and release-status routes. It exports static files and has no backend, analytics, forms, account or external font service. Download actions point to an honest release-status page until the production candidate is accepted. Policy/contact/hosting details are drafts requiring owner review.
- Four original Retina native-window screenshots and a 21.37-second H.264 recording at 840 × 1280 / 30 fps, with deliberate playback, native controls, captions and a text description. [Media provenance and SHA-256 values](../../website/public/assets/provenance.json) bind the images and recording to the isolated Debug sample build. The app window is genuine; the surrounding blue workspace and fictional Juniper brief are original illustrative content. No copy completion, upload or signed-release success is simulated.
- Consent, neutral core tasks, existing-workflow baseline, assistance rules, recruitment copy, an observation sheet, manual seven-day diary and an unfilled report. Real responses belong in ignored private storage. The proposed thresholds remain six of eight unaided, five of eight on three distinct dates, and four of eight choosing to keep installed. Purchase validation is retired because Nivlet is free.
- A versioned review manifest and exact-candidate release checklist, including inherited native/distribution checks, tested configurations, final support/policies, integrity, withdrawal and rollback. These are preparation, not certification. No public installer or previous trusted release is invented.

The owner requested `website/`, then rejected the initial Alcove/Klack direction and requested another reference. The implemented direction follows the supplied Homerow and CleanShot captures: white canvas, compact navigation, restrained system typography, a blue desktop and actual app windows. Next.js and Tailwind were explicitly requested and implemented. The provisional website glyph does not settle the app’s visual identity. Third-party reference artwork and fonts are not shipped.

Applied the Sites skill in its local-only workflow and the repository’s writing, typography, layout and accessibility skills. Sources for framework setup: [Next.js installation](https://nextjs.org/docs/app/getting-started/installation) and [Tailwind’s Next.js integration](https://tailwindcss.com/docs/installation/framework-guides/nextjs). No Sites registration, upload, source synchronization or deployment was performed.

## Native media environment and method

M3 MacBook Air, arm64, macOS 26.6.2 (25G83), Xcode 27.1 (27A9275), macOS 27 SDK, Swift 6.4. The media app uses the current native source without product changes, bundle `ashique.nivlet.phase8media`, Debug `NivletPreview YES`, in-memory synthetic content and a 420 × 640-point panel. It never opens the production library. The helper only targets that bundle; recording excludes other windows and audio. It does not press Copy or write to the general clipboard.

`scripts/capture_phase8_media.swift` selects the isolated window through ScreenCaptureKit and captures stills with its exact window ID. It uses real keyboard input and verifies that the native template reports “2 of 2 filled” before accepting the filled screenshot. It shows Prompts, fills Explain a concept, shows References and Scratchpad, then returns to Prompts. This is not a drag-destination, persistence, model-response or end-to-end clipboard acceptance test.

Reproduce with a fresh output directory, from the repository root:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/Phase8Media \
  PRODUCT_BUNDLE_IDENTIFIER=ashique.nivlet.phase8media PRODUCT_NAME=NivletPhase8Media build
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path build/Phase8CaptureCache \
  scripts/capture_phase8_media.swift -o build/capture-phase8-media
open build/Phase8Media/Build/Products/Debug/NivletPhase8Media.app --args \
  -NivletPreview YES -NivletOpenOnLaunch YES -NivletAppearance dark -NivletTool prompts \
  -shell.introductionCompleted YES -shell.fullHeight NO -shell.panelHeight 640 \
  -shell.panelWidth 420 -shell.textSize standard
build/capture-phase8-media build/Phase8CapturedMedia
```

Capture helper runtime requires macOS 15+; the native app’s provisional macOS 14 floor is unchanged. Xcode macro services, app launch and recording needed reviewed execution outside the tool sandbox. The final captured source recording was re-encoded with FFmpeg (`-an -r 30 -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart`); its timeline and content are retained. `ffprobe` confirms 840 × 1280, 30 fps, 21.366667 seconds, 873,889 bytes and no audio stream. Sample frames and every still were visually inspected.

Initial attempts are not passing evidence: the first build could not invoke sandboxed compiler services; an initially tucked window could not be selected; AX value assignment changed the visible editor without updating SwiftUI’s model, so it was replaced with actual typed events and a rendered-progress assertion. One earlier recording ended with an already-stopped stream error; it was discarded. The final capture run completed successfully. No native behavior fix is claimed from correcting the capture helper.

## Website verification

Node 22.21.1, npm, Python 3.9.6; Next.js 16.4.3, React 19.3.1, Tailwind 4.3.3 and TypeScript 7.0.2 pinned in `website/package-lock.json`. Browser checks use an isolated Chrome context, not a personal browsing session. The current record of final commands/results is in [verification.json](phase8-release/verification.json).

```sh
cd website
npm ci
npm run build
npm run typecheck
npm run verify
```

Native product sources are unchanged, so the full Swift correctness suite was not rerun for website/doc-only changes. The historical Phase 7 total remains 124 tests / 213 cases plus nine distribution-tool tests; it is not a new Phase 8 test result.

Final website build, TypeScript and export verification passed: **9 HTML files, 211 local references/anchors and 8 asset hashes**. All five supporting routes returned HTTP 200. The production export reflowed at 1440, 390 and 320 CSS pixels without horizontal overflow. All four screenshot buttons selected and decoded the correct native image. The recording loaded its 21.37-second duration and caption track without a media error or autoplay. The dialog received focus; Escape closed it, paused playback and returned focus to its trigger. Reduced-motion emulation disabled smooth scrolling. No browser console errors or warnings were observed. [Actual desktop website capture](phase8-release/website-desktop.png).

The scoped writing/layout/typography/accessibility review found no remaining blocking issue in these inspected states. **Not verified:** spoken website screen reader, a full keyboard traversal, actual 200% browser zoom and an automated accessibility audit. The browser checks do not close the app’s native accessibility gate.

During verification, ignored native build output, `.next/` and installed website dependencies were removed externally while the preview server was running. The source and captured website media remained intact. Dependencies were restored from the lockfile before final checks. The old `build/Phase7Review` artifact is unavailable at final review: the review manifest labels its checksum/signature as historical Phase 7 evidence, without claiming a fresh artifact verification.

## Open gates

| Area | State |
|---|---|
| Study | No recruitment, consented sessions or return-use observations. Validation decision pending. No outreach sent. |
| Native acceptance | Phase 6 remains open: complete VoiceOver/keyboard, focus/display/Spaces and recorded destination/runtime checks. |
| Distribution | No Developer ID candidate, notarization/stapling, clean-Mac/offline first launch or real signed update/rollback evidence. |
| Final policies/support | Drafts available; publisher identity, dedicated contact/withdrawal route, hosting/log retention and final terms need review. |
| Release media | Captured against an isolated Debug preview; recheck against the accepted final release. |
| Publication | None. No domain registration, paid service, external submission, tester invitation or public download performed. |

Preparation is reviewable. Phase 8 remains incomplete until actual validation, inherited technical gates, final support/policies and authorized publication/live verification are resolved.

## Website download (1 November 2026)

At papi's request, the website now serves the app directly; Nivlet is not distributed through the App Store. `scripts/distribute.py build --local --version 0.1 --build-number 2` produced `build/WebDownload-0.1-2` from `d34ce98` (native source clean; unrelated website edits present). `distribute.py verify` passed: checksum, image integrity, read-only mount and disposable install copy. The full native suite passed on the same source (`** TEST SUCCEEDED **`, log `build/web-download-tests.log`).

`website/scripts/sync-release.mjs` copied it to `website/public/download/Nivlet-0.1.dmg` (build 2 at first; now build 3, below) and wrote `website/lib/release.json`. The header, hero and final call to action download it; `/releases/` shows version, requirements, install steps and the checksum. `npm run build`, `typecheck` and `verify` (which now checks the DMG bytes against `release.json`) passed. A local static server returned the image as `application/x-apple-diskimage` with a matching hash. Screenshots were checked at 1440, 390 and 320 CSS pixels.

**This download is ad-hoc signed and not notarized.** There is still no Developer ID identity (`security find-identity`: 0 valid). On first launch macOS will block it until the user clicks Open Anyway in System Settings → Privacy & Security; the release page explains this. Developer ID signing and notarization, clean-Mac and update checks remain open. No deployment was performed.

Build 3 (same day) adds the app icon. The DMG previously showed macOS's blank placeholder because the target had no asset catalog. `scripts/make_app_icon.swift` builds `Nivlet/Assets.xcassets/AppIcon.appiconset` (16–1024 px) from the proposed nivlet-v1 `favicon-master.png` on Apple's 824-on-1024 rounded-square grid. Both app configurations set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. `distribute.py build/verify` passed for `build/WebDownload-0.1-3`; the bundle contains `AppIcon.icns`, and `CFBundleIconName` is `AppIcon`. The website now serves that image: 2,706,316 bytes, SHA-256 `efa2fdc67c12bf4ee460b28433045ee33fd1243fe798f4001bc58a31f76eb2bc`. Website build and verify passed. The native test suite was not rerun for this asset-only change.

Build 4 (same day) replaces the in-image `Install and recovery.txt` (`docs/distribution-install.txt`). The old file told public users the download was an untrusted internal candidate. The new one gives user-facing steps: install from Applications rather than the disk image, the one-time Open Anyway approval (click Done, not Move to Trash), updating, recovery and uninstalling. The website adds the same warnings and an uninstall section. `build/WebDownload-0.1-4` passed `distribute.py verify`; the site serves 2,706,393 bytes, SHA-256 `463c5db141881cfaa34cd7f2e76f573378ac44ddc4b4a4ac649546f90a8095cf`. Website build, typecheck and verify passed.

Build 5 (same day), at papi's request, adds the first-run and install polish found while reviewing the download:
- **Menu-bar icon:** the Nivlet N as a template image (`MenuBarIcon`, generated by `scripts/make_app_icon.swift`), replacing the generic `sidebar.right` symbol.
- **Open at login:** a settings toggle using `SMAppService.mainApp`. It is off by default and disabled while the app runs from the disk image.
- **Running from the disk image:** when Nivlet runs from `/Volumes/…` or App Translocation, an alert asks the user to move it to Applications and offers to quit and open that folder.
- **About and updates:** the menu adds About Nivlet (with copyright) and Check for Updates…. The latter opens `/releases/?installed=&build=`, and the page says whether a newer build exists. The browser makes the request; the app gains no network entitlement.
- **DMG window:** a Finder layout with background, arrow and positions, and a volume icon.
Results: the native suite passed with 219 test cases (`** TEST SUCCEEDED **`), including new `InstallLocationTests`. The nine distribution-tool tests passed, and `distribute.py build/verify` passed for `build/WebDownload-0.1-5b`. The compiled `Assets.car` holds `MenuBarIcon` in template mode at 18 and 36 px. Running the DMG copy showed the alert; Quit and Show Applications opened `/Applications` from inside the sandbox. The opened DMG window was screenshot-checked. On this dark-mode Mac, Finder drew dark labels on the light background. The website serves 2,891,474 bytes, SHA-256 in `website/lib/release.json`. Website verify now decodes URL-encoded dynamic-route chunk paths. Not checked here: a screenshot of the menu-bar item (the menu bar was hidden during capture), the Open at Login round trip, and Light-mode DMG rendering.

## Real Codex website walkthrough (1 November 2026)

The video section now shows the owner-authorized real Codex desktop app: two saved prompts copied/pasted from an isolated Nivlet library, and an original sidebar reference dragged into the unsent composer. The 27-second full-desktop video, matching player controls, text alternatives, copyable examples and local checks are recorded in [the workflow media review](phase8-release/website-codex/README.md). This is website/media evidence, not completion of a native or release gate. No deployment was performed.
