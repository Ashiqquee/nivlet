# Website video — Nivlet beside Codex

1 November 2026. Website and recording changes only; native acceptance/release gates remain open.

The owner requested a video showing saved prompts copied from Nivlet into the already-open Codex app, plus a sidebar-layout image dragged into the chat. A later review requested everyday wording, the entire desktop throughout, matching player controls, cleanup, and commits/pushes in both repositories.

The final 26.967-second H.264 video is 1440 × 900, 30 fps, 719,160 bytes, faststart, without audio. Both real apps stay visible throughout on every screen size. Labels say “Pick a saved prompt,” “Click Copy prompt,” and “Drag an image into your chat.” No sidebar zoom or portrait crop remains. The two technical example prompts are the owner’s supplied saved content, not instructions executed by this work or a measured 50% improvement claim.

The charcoal/amber player provides play/pause/replay, a seek slider, time, description captions and fullscreen. Arrow keys seek five seconds; Escape exits fullscreen. Controls remain visible and have keyboard focus indicators. Native controls remain in the server-rendered fallback. `preload="none"` means zero MP4 requests before playback. Expandable steps, a downloadable walkthrough and exact-copy example prompts remain available.

## Capture and source

M3 MacBook Air, arm64, macOS 26.6.2 (25G83), Xcode 27.1 / macOS 27 SDK. The isolated native build passed using `xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' -derivedDataPath build/WebsiteWorkflow PRODUCT_BUNDLE_IDENTIFIER=ashique.nivlet.websiteworkflow PRODUCT_NAME=NivletWorkflow build`. Compiler services required reviewed execution outside the tool sandbox.

The native app used only its synthetic `verification-website-demo-v1` SQLite library. ScreenCaptureKit included its panel and the owner-authorized Codex window (`com.openai.codex`). No working pocket was opened. Both pasted prompts were copied back from Codex and compared exactly with the saved strings. A real pointer drag produced a visible image thumbnail in the unsent composer. No prompt was submitted and no model response is shown. Clipboard preservation stayed in memory and was restored conditionally.

The opening uses the verified empty-chat → first-paste portion of `build/WebsiteCodexCapture-v2`, retained as `copy-source-v1.mp4`. The rest uses the complete accepted capture (`build/WebsiteCodexCapture-v3`), retained byte-for-byte with `capture-v1.json` in the separate website repository’s `artwork/workflow-demo/`: 2940 × 1912, 60 fps, 39.783 seconds. The unused remainder of the opening take and other failed focus/window/control takes are excluded. The retained capture helper now requires a fresh Codex draft and both windows on the same Space; its final source compiles, while the accepted footage predates that precondition refinement. The opening now shows the actual empty Codex composer before the first paste.

`python3 scripts/render-workflow.py` in the website repository renders the final video, poster, captions, walkthrough and edit manifest. It removes idle/verification intervals, retains original action speed, and adds plain step labels. No copy, attachment or sent-message state is fabricated. The original Northstar sidebar/board reference was drawn with AppKit; no third-party UI artwork is shipped.

## Checks and cleanup

Node 22.21.1, Python 3.9.6, locked website dependencies and isolated Chrome against the static export. `npm run build`, `npm run typecheck` and `npm run verify` passed: 9 HTML files, 325 local references, 6 original native hashes and 15 design/media hashes. [Recorded checks](checks.json).

Browser checks passed for play/pause/replay, a chapter selected before metadata, all four chapters, eight caption cues, slider keyboard seeking, actual fullscreen with controls, Escape exit, and visible keyboard focus. At 1440, 390 and 320 CSS pixels there was no horizontal overflow, including expanded long prompts; player buttons remain 44 × 44 px. Exact example copying and its denied-permission recovery were tested with a browser clipboard stub, without replacing the Mac clipboard. No console errors or warnings were observed.

Inspected [desktop](desktop.webp), [fullscreen](fullscreen.webp), [390 px](mobile-390.webp) and [320 px](mobile-320.webp). Obsolete guided video edits and the new sidebar-only portrait variant were removed. Build output, logs, dependencies, local databases, credentials and failed takes remain ignored. Source media and the original sample screenshots remain because they support reproduction and provenance. The render script now lives with its assets in the website repository.

Not verified: Safari/Firefox, a physical iPhone or its native fullscreen fallback, spoken VoiceOver, actual 200% zoom, a full-site accessibility audit, or other destination apps. No native product code changed; the Swift correctness suite was not rerun. Git pushes are authorized by the owner; hosting may follow the website repository’s existing integration, without certifying a native release.
