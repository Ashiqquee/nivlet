# Phase 3 — templates and original-file references

29 October 2026 · **Local gate passed** · [Deliverables](../phases/phase3_deliverables.md)

## Grammar decisions

Named blanks are opt-in. Plain prompts preserve all braces and backslashes literally. In blank mode:

- Names use ASCII letters first, then ASCII letters, digits or underscore. Names are case-sensitive and repeated names share one input, in first-appearance order.
- Lone `{` or `}` is an error. Whitespace inside a token, including `{{ name }}`, is an error rather than trimmed implicitly.
- Backslash escapes one immediately following brace. Backslashes before other characters and trailing backslashes stay literal.
- To render a backslash followed by a literal brace, use two backslashes followed by the brace: the first stays literal, the second escapes the brace. Each brace of a literal token must be escaped individually.
- Inserted values are literal, preserve whitespace/Unicode/line endings and are never parsed a second time. Whitespace-only required values block Copy.

Source edits and explicit Reset affect only the local filled draft, never overwrite the saved source with filled text. Exact copy retains Phase 2's unchanged-string policy.

## Implementation

Prompts remain one tool: plain text or opt-in named blanks. The parser's preview spans now drive both the styled preview and renderer/Copy, so literal values cannot acquire a second interpretation. The native text editor underlines the malformed brace and announces a diagnostic. Source changes require the existing filled-draft warning and clear the old fill values when submitted, including a submitted save that remains pending. Reset and cancelling Reset leave saved source unchanged. Switches have explicit accessible names; case-distinct field names are disambiguated in the field UI.

The native shell now protects SwiftUI confirmation sheets/windows during key-window transitions. Opening Reset must not tuck an unpinned panel. This also preserves the platform boundary for focus behavior. The minimum-width footer keeps Actions on one line; import recovery buttons also stay intact while failure results take layout priority. Inconclusive pasteboard metadata and unresolved declared file URLs produce an actionable import failure rather than silently consuming Paste.

`ReferenceAssetStore` owns file work on a separate serial actor. It opens only regular local files with `O_NOFOLLOW`/`O_NONBLOCK` and `fstat`, rejects folders/symlinks/pipes/remote URLs, streams 1 MiB chunks into staging, hashes the bytes actually written, synchronises the staged file, then places/adopts a read-only digest asset. Source files are read, never moved or edited. Metadata is committed only after placement; a pending metadata failure is explicitly marked Not saved and retries the same staged reference ID. Interruption can leave an unreferenced original; it is retained safely rather than deleting bytes that may be needed by recovery or Undo. Phase 5 still owns comprehensive orphan cleanup/export/restore.

The Phase 2 SQLite schema remains **4**. References retain independent original filenames, labels and notes even when bytes deduplicate. Image flags are derived from actual ImageIO type/header metadata, including on load, rather than a filename extension or the mere existence of an image-source object.

File picker, Finder drop and user-initiated file/image paste feed the same intake. Paste uses `paste:` through the responder chain; Command-V and Edit ▸ Paste route reference files/images to the shelf while inspectors/text editors keep ordinary text paste. No clipboard monitoring or custom read button was added. Menu validation uses metadata detection on macOS 15.4+ (the installed SDK exposes refined Objective-C spellings), with declared-type fallback on macOS 14 and while detection is pending. Pasted image data is owned without re-encoding. A Debug-only named pasteboard can be injected into a verification library, avoiding the working clipboard during native checks.

Import results show each name and saved/failure/confirmation state, with counts. Retry failed targets only retained failed requests. A metadata retry needs no original source because staged bytes already exist. Choose again opens a single-file native picker when a URL no longer grants access, replacing that failed request rather than reimporting successes. Picker Cancel retains the previous result. Result/retry history is session-local; committed metadata and pending-library recovery survive restart.

Provisional file policy: warn above **100,000,000 bytes**, require an explicit Import anyway above **500,000,000 bytes**, refuse above **2,000,000,000 bytes**. Streaming also checks the actual bytes read so a growing source cannot bypass the cap. These are provisional PRD values, not measured maximum-size performance claims.

Reference labels and notes are editable independently of filenames/bytes. Static previews run off-main: images are downsampled (480 px thumbnails, 1200 px inspectors; API clamps to 1600 px, with a 64-megapixel source guard), PDFs render their first page through Core Graphics, and UTF-8 previews read at most 32 KiB with a truncation notice. Unsupported/encrypted/binary content gets a generic fallback. HTML and source code appear only as literal text. No WebView, active scripts, external resources or OCR are involved.

Drag prepares a disposable export in the background for the highlighted reference/inspector. The drag callback does no copying or hashing on the UI actor. If preparation is still running, persistent feedback explains the retry; keyboard users can Reveal in Finder instead. Every transfer gets an independent read-only export; a receiving app that edits an old export cannot poison a later one. Exports of digest-owned assets are verified before use. They remain available for 24 hours and are not deleted at drag end. Copy note, Copy file and Drag file remain distinct. Copy file offers the unchanged original file URL/path; images up to 20 MB also offer their original encoded image bytes, without resizing or converting them. Larger images still offer the original file, without an unbounded inline image decode.

## Verification

Environment: Apple M3 MacBook Air, arm64, macOS **26.6.2 (25G83)**, Xcode **27.1 (27A9275)**, macOS 27 SDK, Swift 6.4 / language mode 6, MainActor default isolation, macOS 14 deployment floor unchanged. No new dependency. New pasteboard detection is runtime-gated at macOS 15.4; all other new behavior retains the floor.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData test
```

**78 tests, 135 cases including parameterized runs; 0 failed, 0 skipped, no runtime warnings or Swift compiler warnings.** Result: `build/DerivedData/Logs/Test/Test-Nivlet-2026.10.29_12-50-01-+0530.xcresult`. Xcode builds/tests ran outside the execution sandbox so its Swift macro compiler/test host could launch. Xcode's existing no-App-Intents metadata notice remains.

Automated coverage includes the grammar cases above; repeated/case-sensitive names, literal token-like/Unicode/multiline values and preview/clipboard byte equality; 20 mixed originals (PNG, PDF, JSON, CSV, HTML, text/source and binary data), removed source fixtures, restart and SHA-256 comparison of every stored/exported original; same-name/different-content and identical-content/different-name cases; partial failures, retry without duplicated successes, source reselection, metadata failures and retry after source deletion; staging/placement failures and cancellation; size/confirmation boundaries with scaled fixtures; bounded image/PDF/text previews; literal HTML and binary fallback; independent exports and corruption rejection; pasted-image ownership and original-byte Copy file data on private pasteboards. All Phase 2 regressions run too.

Native verification uses only the **`ashique.nivlet.phase3review`** review bundle, its isolated verification library and the **`nivlet-verification-phase3`** pasteboard. The working app/library and clipboard were not used. AX actions and key events targeted that review process.

| Native check | Result |
|---|---|
| Template editor | Malformed spaced token remained in the editor with a diagnostic; valid source saved. |
| Fill/preview/Copy | Required blanks blocked Copy. Repeated values containing literal `{{braces}}` and Unicode appeared identically in the preview and private clipboard. |
| Reset | Both Keep values and confirmed Reset worked with the panel unpinned; saved source retained its tokens. |
| Files and failure UI | Command-V imported multiple fixture files, reported a per-file failure and exposed Retry failed/Choose again. The picker completed a replacement without duplicating successful records. |
| Reference metadata | Label rename and separate note persisted; Copy note produced exactly the note. Original filename/bytes stayed independent. |
| Image paste | Command-V and standard Edit ▸ Paste both imported PNG bytes through the same intake. |
| Restart/source removal | Native quit flushed the scratchpad; template, reference label/note and scratchpad survived relaunch after disposable source fixtures were removed. The final five-reference fixture library passed original-byte/digest checks. |
| Finder fallback | **Finder 26.4** opened the disposable export folder, exposed the intended original filename and its copy matched the original bytes after source removal. |

[Observed native checks](phase3-vertical-slice/native-checks.txt) · [Reference inspector](phase3-vertical-slice/reference-inspector-dark.png) · [320 × 360 footer](phase3-vertical-slice/footer-320x360-dark.png) · [Minimum-size failure controls](phase3-vertical-slice/import-error-320x360-dark.png)

A native picker automation attempt initially selected an unintended file. The filename/digest verification rejected that fixture outcome; its imported metadata, asset and isolated export copies were removed, without modifying its source. The intended fixture was selected explicitly and the final library was verified by name and digest. No private file contents are included in the evidence artifacts. This is a test-harness correction, not evidence that an arbitrary picker selection matches a requested filename.

## Handoff matrix and limits

| Destination/path | Evidence | Status |
|---|---|---|
| Finder 26.4 · Reveal/manual attachment | Actual Finder export window, filename and original bytes | Passed on this host |
| File URL drag representation | NSItemProvider exposes/loads the disposable file URL and file type; exported digests match | Automated boundary passed; physical destination drop not verified here |
| Copy file / Copy note | Private native pasteboards, unchanged original image/file bytes and exact note text | Passed |
| Browser chat, VS Code/Cursor, native AI clients | No uploads or messages sent during this phase | Not verified; no destination compatibility promise |

The local Phase 3 gate is satisfied through template correctness, original-file integrity, explicit failure handling and the tested Finder fallback. This does not close Phase 1's display/Spaces/external-drag checks or final AC-03/AC-04 release compatibility evidence. Network was not disabled on the host; the exercised workflow is local with no account/provider/network operation. macOS 14/27 runtime, Intel, full VoiceOver/Full Keyboard Access, reduced-motion preference toggles, actual >500 MB/2 GB transfers, physical power loss and process termination inside a live asset copy remain untested. Numeric size policy and interruption points were exercised with bounded fixtures/injection rather than exhausting RAM/disk. Multiple pockets, archives/restore, durable trash and licensing remain later phases.
