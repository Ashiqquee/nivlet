# Phase 7 — distribution preparation and update recovery

30 October 2026 · **Local work verified; signed distribution gate open** · [Deliverables](../phases/phase7_deliverables.md) · [Runbook](../distribution.md) · [Content-free results](phase7-distribution/verification.json)

Nivlet is free. The obsolete licence, trial, fee-economics and checkout deliverables have been removed from Phase 7 to match the owner's decision. AC-07 is retired. No account, entitlement, payment, updater service, external submission or publication was added.

## Implemented and verified locally

- `scripts/distribute.py` builds a Release arm64 app and compressed DMG with an Applications shortcut and installation/recovery instructions. Local and Developer ID signing are explicit, separate modes. Version/build, source commit/dirty state, architecture, deployment floor, entitlements, signature and hashes are recorded. Existing output directories are preserved; failed builds cannot become successful candidates.
- Release uses explicit App Sandbox and user-selected file read/write entitlements, Hardened Runtime and no injected debugger permission. The earlier Phase 6 ad-hoc Release output contained `get-task-allow`; the new candidate does not. Debug retains its normal debugging setup. App identity, activation policy and schema 5 are unchanged.
- Artifact checks require the intended entitlements, architecture/floor and signature. Signed mode requires the matching available Developer ID Application identity/team and secure timestamp; it never falls back to ad-hoc. Missing identity was exercised through the actual CLI and stopped before output creation.
- The explicit notarization command preserves the original signed input and prepares an app submission, app stapling, a newly packaged/signed DMG submission, image stapling and trust assessment, saving reports and recalculating hashes after stapling. **This path is prepared but has not been executed with production credentials.** Local/failed/tampered input refusal is tested before any submission.
- DMG verification checks the final checksum and `hdiutil` integrity, mounts read-only, checks the Applications link/instructions, copies the app into a disposable Applications directory and compares its signature, entitlements, version and executable hash. No production application is launched or installed by this checker.
- New native tests cover same-schema reopening, recoverable pending text after rollback/interrupted commits, two-pocket ordering/active identity, trash, original bytes after source deletion, independent closed-root backup/recovery copies and future-schema refusal through the app model, including retry/flush attempts. Existing migration snapshot/transaction rollback, retained-original and portable-recovery tests ran in the full suite. The tests are storage/model boundaries, not real signed binary update evidence.

## Environment and commands

Apple M3 MacBook Air, arm64, macOS 26.6.2 (25G83), Xcode 27.1 (27A9275), macOS 27 SDK, Swift 6.4 with language mode 6, MainActor default isolation and Approachable Concurrency, Python 3.9.6. Provisional runtime floor remains macOS 14; no macOS 14/27 runtime or Intel hardware was available. Swift Testing guidance was applied to the new isolated fixtures. There were substantial pre-existing uncommitted Phase 6/native-interface changes; those were preserved and included in the tested app.

Executed from the repository root:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Nivlet.xcodeproj -scheme Nivlet -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -resultBundlePath build/Phase7Regression.xcresult test
python3 -m unittest discover -s scripts -p test_distribute.py -v
python3 scripts/distribute.py build --local --output build/Phase7Review
python3 scripts/distribute.py verify --input build/Phase7Review
security find-identity -v -p codesigning
git diff --check
```

Native regression: **124 tests / 213 cases passed**, zero failures/skips/runtime warnings. Distribution tooling: **9 tests passed**, including tampered images, unsafe manifest paths, local/failed candidate submission refusal, wrong certificate type/team, missing identity, output preservation, debugger/unrelated permissions, sandbox and Hardened Runtime checks. Release build, actual image verification, mount and disposable install copy all passed. Xcode emitted its existing no-AppIntents-dependency metadata notice; no Swift compiler warnings were found. No new runtime/performance/appearance claims are made.

Logs/results are local: `build/phase7-regression.log`, `build/Phase7Regression.xcresult`, `build/Phase7Review/build.log` and the candidate manifest/checksum. The new tests use disposable roots; working pockets and the general clipboard were not used. Native builds/tests and image verification required reviewed execution outside the tool sandbox because it blocks Swift macro services, `testmanagerd` and disk-image services.

Initial attempts are not passing evidence: sandboxed builds/tests could not reach required services; a subsecond trash timestamp in the new fixture did not round-trip exactly through SQLite decimal timestamps (replaced with an exact epoch fixture); disabling base-entitlement injection also removed generated sandbox permissions (fixed with an explicit Release entitlement file); the installed `codesign` emits a text entitlement format unless `--xml` is requested (fixed and checked against the real artifact). Final runs above pass.

## Local artifact

| Field | Recorded value |
|---|---|
| DMG | `build/Phase7Review/Nivlet-0.1-1-arm64-LOCAL-UNNOTARIZED.dmg` |
| Size | 1,780,364 bytes |
| DMG SHA-256 | `f648bc87c0650a8d98b75af1f233b4516bdb62b0861ae5556d99c70a467f46da` |
| Executable SHA-256 | `cc557bbeb0606eae1275486a1d51ebac0e436ef61a017a5ea661f5530ec21ba0` |
| Version/build | 0.1 / 1 |
| Architecture/floor | arm64 / macOS 14.0 deployment target |
| Signature | Ad-hoc, Hardened Runtime; strict/deep verification passed |
| Permissions | App Sandbox; user-selected files read/write |
| Source | `282a0ab8dfe8a32bf08eb01688d52b87ec9a83a0` plus dirty working tree |
| Trust status | **Local, unnotarized; not release-ready** |

Generated output is ignored by git; only content-free verification metadata is retained in source. The artifact is a local review specimen, not a public download or final release candidate. No signing credentials or private library data are included.

## Open gates and dependencies

| Gate | Actual state / next evidence |
|---|---|
| Phase 6 native acceptance | Still open: spoken VoiceOver, display/Spaces, destination/runtime checks; see [Phase 6](phase6-beta.md) and [native refinement](native-redesign.md) |
| Developer ID | `security find-identity` reported **0 valid identities**. Existing membership/team and final identity need owner setup; no purchase/import performed |
| Notarization/stapling | Not submitted. Requires an available signing identity, Keychain profile and authorized Apple submission. Actual signed-mode/tool behavior remains unverified |
| Clean-Mac Gatekeeper | Not run. Requires the exact production-signed artifact, quarantine-preserving transfer and a clean test environment |
| Disconnected first launch | Not run. Requires clean state and the stapled app/image; a local offline model test is insufficient |
| Signed updates and rollback | No previous production signed release exists. Actual previous/new binary replacement, failed replacement, signing-container continuity and compatible rollback remain pending |
| Runtime support | macOS 14/27 runtime testing unavailable; Intel support unresolved. arm64 compilation does not establish these claims |
| Public release | Not performed; belongs to authorized Phase 8 work |

The [distribution runbook](../distribution.md) supplies concrete credential, submission and acceptance steps, plus a recovery procedure that preserves full closed-library roots, originals and pending data. Schema migrations retain existing consistent backups and reject newer schemas. Manual replacement does not require deleting data, and a database-only snapshot must never be treated as a complete backup of the filesystem.

Phase 7 remains **in progress**. Local implementation is ready for review; signing, clean-Mac installation, real signed updates and the inherited native gate must pass before completion.
