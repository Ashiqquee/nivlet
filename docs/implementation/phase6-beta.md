# Phase 6 — local beta implementation and measurements

30 October 2026 · **In progress; final native acceptance gate open** · [Deliverables](../phases/phase6_deliverables.md)

**Latest UI:** the owner-requested [native redesign](native-redesign.md) replaces the initial text-heavy introduction and refines the shelf. Its captures and 122-test / 210-case result supersede the earlier UI captures and correctness totals below. The performance distributions below are historical measurements of the preceding Phase 6 UI, not remeasurements of the new illustration. The final acceptance gate remains open.

The local implementation adds first run, a removable sample pocket, shared access/display settings, 100–200% text enlargement, keyboard focus fixes and reproducible beta measurements. This is the current **four-tool** product: Prompts, References, Project pockets and Scratchpad. Instructions merged into Prompts before this phase; the old five-tool wording is corrected.

The Phase 6 exit gate has **not** passed. AC-01–AC-06 and AC-08 need complete native evidence, including spoken VoiceOver and the desktop/destination checks below. This record does not authorize Phase 7 release readiness or broaden support claims.

## Implemented behavior

- A new blank library opens a short, optional introduction inside the existing panel. Start blank retains its empty pocket. Add sample pocket creates a separate, ordinary pocket with two original text prompts (one with named blanks) and a checklist. Existing material is preserved. The sample can be deleted/restored through normal pocket recovery. Repeated submission or a failed-save retry keeps one sample identity. Existing nonblank libraries skip automatic onboarding; Quick start remains available in Settings.
- Quick start explains open/tuck/pin, deliberate copy/paste/attachment and local privacy. Shared Settings are available from both the rail and menu bar: appearance, text size, edge, display, tab visibility, full height and the optional shortcut. The existing ⇧⌘Space shortcut remains off by default and checks system/other-app registration conflicts. It does not request Accessibility or Input Monitoring.
- Device-local text sizes are 100%, 125%, 150% and 200%. Shelf text, forms, native text editors and archive previews scale; ordinary text starts at 13 pt. Decorative key hints and the compact tool rail retain their chrome sizes. Search simplifies its scope control at enlarged sizes, footers/command rows can grow, and empty states scroll. Archive previews fit the available panel bounds. Complete text remains available in scrollable previews.
- A native field bridge focuses the attached title or new-to-do field when an editor is inserted into an already-open panel. Validation can request focus again. Native editing keeps ordinary selection/undo and disables smart quote/dash/text replacement. AppKit first-responder handling stays in `Platform/`.
- Escape clears an active query before tucking, after the innermost preview/action/editor has been handled. Unsubmitted draft confirmation and save-failure recovery remain intact. Return/arrow shelf routing is limited to the shelf/search focus context so other controls retain their key handling.
- Custom button styles expose a visible focus outline. Prompt accessibility values identify their pocket/type. Copy already announces native clipboard completion; failed saves and archive errors now also request a native announcement. Archive error text uses primary ink instead of low-contrast red text.
- A root Reduce Motion transaction suppresses child transitions in addition to the existing shell/tab motion guards. The measured ordinary opening/tucking duration is now 140 ms, replacing the prior 300/240 ms timing. No new dependency, network feature, provider integration, analytics, account, payment or permission wall was introduced.

The actual Refbox [compact shelf/preview capture](../../references/ui-ux/refbox/05-hero-demo-06s.png) and the approved launcher-style native screenshots informed these changes. Existing `ShelfStyle` materials, SF Symbols, tool hues and rail placement are retained. No captured artwork is shipped.

Applied the repository's macOS design, Apple HIG, SwiftUI, accessibility, concurrency and Swift Testing guidance. Focus implementation was checked against the installed SDK; native status announcements follow [Apple's announcementRequested API](https://developer.apple.com/documentation/appkit/nsaccessibility-swift.struct/notification/announcementrequested). Text enlargement is an app setting because macOS has no Dynamic Type setting.

## Environment and correctness

Apple M3 MacBook Air, arm64, macOS 26.6.2 (25G83), built-in Retina display; Xcode 27.1 (27A9275), macOS 27 SDK, Swift 6.4, language mode 6, MainActor default isolation and Approachable Concurrency. Deployment floor remains macOS 14. No macOS 14/27 runtime or Intel machine was available.

The complete regression set covers parser/literal/blank rules; exact Unicode, whitespace, checklist and source bytes; SQLite rollback/disk-full/interruption/relaunch; scoped ownership/Undo/trash; staged originals, previews and import retry; migration rollback/retention; portable archive validation, malicious frames and clean-root restore. Phase 6 adds sample ownership/retry/relaunch/deletion recovery, settings persistence, query Escape/draft preservation and measured 200/1,000-item fixtures.

**121 tests / 209 cases passed; zero failures, skips or runtime warnings.** Final result: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.30_15-38-49-+0530.xcresult`. Isolated timing result: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.30_15-12-35-+0530.xcresult`. Ad-hoc Release and isolated native builds passed. Xcode emitted only its existing no-AppIntents-dependency metadata notices, with no Swift compiler warnings. [Content-free summary](phase6-beta/verification.json). Tests use disposable roots and private pasteboards. The review app is a separate bundle, `ashique.nivlet.phase6review`, with `verification-phase6-*` libraries and `nivlet-verification-phase6` pasteboard. The working library/general clipboard were not used. Xcode/macOS verification requires execution outside the tool sandbox; the sandbox initially prevented the Swift macro compiler service from running.

An initial new disk-full test incorrectly assumed the small sample would require SQLite page growth; it did not. The sample test now uses deterministic transaction rollback. Existing larger fixtures still exercise real connection-scoped SQLITE_FULL. Early helper failures also exposed inherited synthetic modifier flags and pointer-open versus keyboard-open focus differences; the reproducible checker clears flags, verifies the frontmost bundle and uses the app's reopen path for keyboard acceptance. Those failed attempts are not passing evidence.

## Performance

Raw distributions are in [phase6-beta/](phase6-beta/), including sample counts, median, p95 and maximum. These are local observations, not universal compatibility guarantees.

| Measurement | Samples | Median | p95 | Maximum | Boundary |
|---|---:|---:|---:|---:|---|
| Warm opening before change | 30 | 249.72 ms | 277.01 ms | 295.97 ms | AX opener to native resting window geometry |
| Warm opening after change | 30 | 113.97 ms | 120.72 ms | 181.37 ms | Same method; 140 ms configured slide |
| Reopen 200 prompts | 30 | 0.89 ms | 1.85 ms | 2.98 ms | SQLite load and complete snapshot materialization |
| Reopen 1,000 prompts | 30 | 4.11 ms | 5.63 ms | 6.15 ms | Same boundary |
| Search 200 prompts | 100 | 0.55 ms | 0.79 ms | 1.07 ms | Metadata search and result construction |
| Search 1,000 prompts | 100 | 2.81 ms | 3.92 ms | 4.14 ms | Same boundary |
| Exact copy and feedback | 100 | 0.08 ms | 0.34 ms | 7.08 ms | Private pasteboard write plus model feedback/announcement request |
| 600-pixel thumbnail | 30 | 9.27 ms | 15.67 ms | 21.91 ms | Off-main decode/PNG encode of bundled public fixture |
| Main-actor heartbeat during decoding | 109 | 3.05 ms | 3.22 ms | 3.39 ms | Actual interval for a requested 2 ms heartbeat |

The isolated timing suite runs serially without other regression fixtures. All reopened contents are compared exactly; searches verify counts/excerpts; copy checks actual pasteboard text and feedback; decoded dimensions must remain bounded. Raw data is attached to the `.xcresult` and exported alongside this report. The load/search/copy measurements exclude SwiftUI painting and are not claims about end-to-end rendered feedback latency. The thumbnail fixture is not a maximum-size-file throughput test.

Warm opening polls CG window geometry every approximately 1 ms after an AX press; completion means position is within 1 pt of its resting target. It includes action delivery/window-server observation, but does not measure text pixels or every animation's final tail. The p95 target below 150 ms passes for this method; the 181 ms outlier is retained. The old timing failed the target and was changed on measured evidence.

Idle CPU: 0.0414 CPU seconds over 30.1646 wall seconds, **0.137% of one core** on average across 30 one-second samples; resident bytes at the end were 37,666,816. The open, pinned introduction was stationary during observation. `lsof -a -p <review PID> -i -nP` returned no socket rows (exit 1). This is a point-in-time connection observation, not a packet capture or proof of every possible network attempt. [Raw idle data](phase6-beta/idle-cpu.json) and [observer script](../../scripts/measure_phase6_idle.py). Native captures are recorded alongside it. The idle script converts the kernel's Mach-time counters through `mach_timebase_info`, rather than assuming nanoseconds on Apple silicon; see Apple's [rusage population](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c) and [task power accounting](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/task.c). No maximum-size, mixed-media 1,000-reference rendering or physical power-loss claim is made. Interrupted imports remain covered by the existing failure/retry suite; that is distinct from large-library UI stress.

## Acceptance and compatibility matrix

| Check/configuration | Evidence/status | Still required |
|---|---|---|
| AC-01 shell, this M3/macOS 26.6.2 | Local open/tuck/reopen, query Escape, ordinary bounds and motion measurements | Edit/click-away focus destination, physical detach/reconnect, wake/resolution, Spaces, full screen and Stage Manager |
| AC-02 plain prompts | Exact native editor/save/preview/copy checks; regression tests | Full mouse and VoiceOver acceptance walk |
| AC-03 named blanks | Existing parser/render/preview-copy correctness suite retained; sample includes a fill-in prompt | Final native keyboard/VoiceOver complete/reset/edit-warning flow |
| AC-04 original files | Existing integrity, bounded preview, per-file retry and Finder-export tests retained; historical [Phase 3 Finder evidence](phase3-vertical-slice.md) | Current external browser/editor/terminal drops and upload confirmation by recorded destination version |
| AC-05 pockets | Isolation, scoped search, moves/duplication/Undo/trash, sample deletion/recovery tests | Complete final keyboard/VoiceOver pocket organisation walk |
| AC-06 recovery | Full Phase 2–5 regression suite, plus sample rollback/retry/relaunch | Final native failed-save/error review walk and interrupted-operation desktop checks |
| AC-08 keyboard | Scripted native command/focus, text-entry, checklist and Escape checks recorded | All controls by Tab/Shift-Tab, full Keyboard Access, all menus/dialogs and spoken VoiceOver |
| Light/dark, 100% and 200% | Selected native fixture captures at compact/ordinary sizes | Every state/long label and all intermediate text sizes |
| Reduce Motion / Increase Contrast / Reduce Transparency | Source guards, semantic text and custom focus tokens inspected | Actual system setting combinations and spoken behavior |
| Built-in display / Apple silicon / macOS 26.6.2 | Locally exercised configurations only | Real display detach, secondary display, clamshell and mixed scaling |
| macOS 14, 15, 27 runtimes; Intel | **Untested** | Real installations/hardware; building for a deployment target is not runtime evidence |
| Safari / Chrome / AI desktop clients / VS Code / Cursor / Terminal | **Untested in this phase** | Exact versions, file formats and actual drop/paste/upload outcomes |
| Unsupported by design | Folder/symlink import, remote/active previews, automatic chat/clipboard reading, auto-paste/send, cloud sync and compressed archive restore | See [requirements](../nivlet-product-requirements.md) and [archive format](../archive-format.md) |

No actual hardware/OS configuration is labelled unsupported merely because it was unavailable. The current full-screen fallback remains menu-bar/Finder/Spotlight access on an ordinary desktop; overlay reliability is not certified. Missing release credentials do not block these local checks, but this ad-hoc build is not a signed/notarized release candidate.

## Reproduce the internal build and checks

From the repository root with full Xcode selected for the command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData test

# Run the timing suite alone after building the tests.
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData test-without-building \
  -only-testing:NivletTests/Phase6MeasurementTests

# Local arm64 Release app + ZIP + SHA-256. Does not upload or notarize.
./scripts/build_internal_beta.sh
```

For isolated native checks, create the review bundle and checker, then use a fresh letters/digits/hyphen fixture suffix. The first-run override is review-only; never point the checker at the working bundle.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/nivlet-phase6-native \
  PRODUCT_BUNDLE_IDENTIFIER=ashique.nivlet.phase6review PRODUCT_NAME=NivletPhase6Review build

xcrun swiftc scripts/verify_phase6_native.swift -o /tmp/nivlet-phase6-verify
open -n /tmp/nivlet-phase6-native/Build/Products/Debug/NivletPhase6Review.app --args \
  -NivletVerificationLibrary phase6-review-new \
  -NivletVerificationPasteboard nivlet-verification-phase6 \
  -shell.introductionCompleted NO -shell.fullHeight NO
/tmp/nivlet-phase6-verify sample
/tmp/nivlet-phase6-verify keyboard
/tmp/nivlet-phase6-verify warm /tmp/nivlet-phase6-warm.json
/tmp/nivlet-phase6-verify quit
```

The core keyboard session uses Pin to avoid app/Space activation tucking the panel during automation; it passes search → query Escape → new prompt → Tab → native text entry → save → search/Return preview → Command-Return copy → Scratchpad → new to-do/Return → tuck/reopen. It checks exact Unicode, literal braces, trailing spaces and the real checkbox role. The final log is [native-checks.txt](phase6-beta/native-checks.txt). Unpinned activation/Spaces remains an explicit acceptance gap.

The five-minute scoped log review inspected 967 system messages from the review process: zero matches for synthetic prompt/pocket/checklist content and 12 OS/XPC error/fault messages (linkd/Intents registration, a canceled XPC session, task-port access and a benign CursorUI ViewBridge disconnect). These were inspected; no content is copied into the retained count summary. Source inspection found no app network client or content logger, and the sandbox entitlements contain no network entitlement. This is a bounded observation, not a claim about every possible OS log or future feature.

The checker requires its host's existing Accessibility/Screen Recording access. Nivlet itself requests neither. Run native keyboard checks separately from test-host launches and avoid interacting with the review app while it owns synthetic keys. A first-run override on a nonblank existing fixture correctly skips automatic introduction. To review it again, choose Quick start from Settings. Native resize/capture modes and `-NivletAppearance light|dark -shell.textSize double` provide isolated visual checks; screenshots contain synthetic content only.

## Native captures

Selected real review-window captures, never working-pocket data or mockups:

| Surface | Artifact |
|---|---|
| Scratchpad, standard text, dark | [420 × 640](phase6-beta/scratchpad-dark.png) |
| Prompts, standard text, dark | [320 × 360](phase6-beta/prompts-320x360-dark.png) |
| Prompts, 200%, light | [320 × 360](phase6-beta/prompts-200-320x360-light.png) |
| Native editor, 200%, light | [320 × 360](phase6-beta/editor-200-320x360-light.png) |
| Quick start, 200%, light | [320 × 360](phase6-beta/quick-start-200-320x360-light.png) |

At 200%, the deliberately short panel shows less content at once. It scrolls; compact key hints/rail glyphs retain their size. The editor scrolls its native initial field into view. These captures are selected visual evidence, not approval of every layout, long label, system contrast setting or accessibility state.

The reproducible beta package is `build/Nivlet-InternalBeta-arm64.zip` with an adjacent SHA-256 file, produced by the checked-in build script. It is an ad-hoc local arm64 build, not a Developer ID/notarized installer. No release, tester outreach or upload was performed.
