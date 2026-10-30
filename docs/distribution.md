# Nivlet distribution and manual update recovery

[Phase 7 evidence](implementation/phase7-distribution.md) · [Deliverables](phases/phase7_deliverables.md)

Nivlet is free. There is no entitlement, trial, checkout, licence issuer or activation server. AC-07 is retired. Optional support is a website link and does not change the app. Distribution uses a Developer ID Application signature, Hardened Runtime, notarization and stapled tickets. Manual updates suffice for v1.

## Local candidate

Requires full Xcode and Python 3.9+. Run from the repository root. Each output directory must be new: failed or older outputs are preserved, never silently replaced. Build output, local signing metadata and notary reports stay under ignored `build/` or `dist/` directories. Keep signing material in Keychain, outside the repo and build outputs.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 scripts/distribute.py build --local --version 0.1 --build-number 1 --output build/Phase7LocalReview
python3 scripts/distribute.py verify --input build/Phase7LocalReview
```

The DMG contains `Nivlet.app`, an Applications shortcut and [installation/recovery instructions](distribution-install.txt). Its filename and manifest say `LOCAL-UNNOTARIZED`. It is an internal packaging specimen; do not distribute it as a trusted release. Verification checks its checksum, image integrity, read-only mount and a copy into a disposable Applications directory. It does not launch the production bundle or touch the working library. Ad-hoc signature verification proves bundle integrity, not Gatekeeper acceptance.

Only arm64 is built. macOS 14 remains the deployment floor, with macOS 14/27 runtime acceptance still pending; Intel support is unresolved. No universal or full-screen support claim follows from a build.

`manifest.json` records version/build, source commit and dirty state, architecture, SDK tool version, host OS, signature, entitlements, executable/image hashes and pending checks. `SHA256SUMS` covers the final image. Builds are reproducible procedures, not bit-for-bit reproducible artifacts: timestamps, signing, disk images and source changes affect bytes. A dirty candidate is useful for local review; record a reviewed clean commit for release.

## Signed candidate

Before production: confirm an existing Apple Developer Program membership, the owner's team and final bundle identifier. Obtain a **Developer ID Application** certificate with its private key in the signing user's Keychain; this task does not create an account, purchase membership or import keys. Changing signing team, app identifier or sandbox policy can affect access to an existing container and must be tested with a previous signed app.

```sh
security find-identity -v -p codesigning
python3 scripts/distribute.py build --identity DEVELOPER_ID_CERTIFICATE_SHA1 --team APPLE_TEAM_ID --version 0.1 --build-number 2 --output build/Phase7Signed
```

Replace the identity with its 40-character certificate SHA-1 and the team with its 10-character ID. Missing/mismatched identities fail before any output directory is created; signing never falls back to ad-hoc. The workflow requires Developer ID Application authority, matching team and secure timestamp, verifies signatures, and signs the DMG. This command does not submit a notarization request. It may contact Apple's timestamp service for signing.

Release builds disable Xcode's base-entitlement injection; Debug builds retain debugger support. The verifier requires App Sandbox and user-selected file read/write, with Hardened Runtime. It rejects any extra entitlement other than application/team identifiers, including debugger attachment, JIT, unsigned executable memory, disabled library validation, network access and unrelated privacy permissions. The current app has no embedded helpers/frameworks requiring separate signing. If one is introduced, extend inside-out signing deliberately; `--deep` is used for verification only.

## Notarize and staple

Use an existing `notarytool` Keychain credential profile. To configure one locally, run `xcrun notarytool store-credentials Nivlet-notary` interactively and follow its prompts. Do not put passwords, API private keys or app-specific passwords in commands, documents, environment files committed to git or build artifacts. Credential setup and submission are separate from local build verification.

The following command uploads the app and DMG to Apple. Run only when that submission is authorized and the candidate is reviewed:

```sh
python3 scripts/distribute.py notarize --input build/Phase7Signed --output dist/Nivlet-0.1-2 --profile Nivlet-notary
python3 scripts/distribute.py verify --input dist/Nivlet-0.1-2
```

The original signed candidate is preserved. A new output copy is checked, zipped, submitted with `notarytool`, and must receive `Accepted`. The workflow staples and validates the **app** ticket, packages the stapled app in a new signed DMG, submits that DMG, requires `Accepted`, staples/validates its ticket and runs app/image Gatekeeper assessments. Both tickets are needed for a useful disconnected first-launch test. Hashes are calculated after final stapling. Submission JSON and available Apple log reports are retained. Failure leaves a failed manifest and reports, with no successful-download status. Retry using a new output directory after fixing the error; submission IDs in the reports permit checking a timed-out request before uploading again.

`status: notarized` records automated distribution checks only. `release_ready` remains false until the manual gates below have evidence; the script never publishes or edits a download URL. Never present a local or failed artifact as notarized. No step asks a user to disable Gatekeeper or strip quarantine.

Apple references checked 30 October 2026: [Developer ID](https://developer.apple.com/developer-id/), [packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution), [customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues). Installed `codesign`, `hdiutil`, `notarytool` and `stapler` remain the command-level references. This guide records Nivlet's workflow, not an Apple certification result.

## Manual release acceptance

Record date, exact macOS/hardware, candidate hashes, previous/new version/build, signing team, quarantine source, command outputs and observable results in the phase evidence. Use non-sensitive sample libraries. Keep data and signing reports private; record only content-free results in git.

1. Complete the Phase 6 native gate; carry its display, focus, VoiceOver, destination and compatibility limits forward.
2. On a clean test Mac/user with no development trust exemptions, obtain the candidate through a quarantine-preserving browser download. Confirm app/DMG signatures, ticket validation and Gatekeeper assessment. Install through Finder's Applications shortcut, eject, launch from Applications, then relaunch. Ensure only one edge tab/menu-bar instance appears and no access permission wall appears.
3. Repeat first launch on a clean state with networking disconnected, using the stapled artifact. Exercise blank/sample start, exact copy, reference import/export and save/relaunch. A successful online launch can warm trust caches, so it is not the disconnected first-launch test.
4. Install the previous trusted signed release, populate two pockets with Unicode prompts, a filled-template draft, references and a checklist; delete source files. Record original hashes. Make both a portable export and a closed full-library backup. Quit before replacing the app. Install the new release, eject and check ownership, order, active view, trash, notes, exact copy and original-byte hashes. Saved templates and scratchpads persist; in-memory filled drafts/unsubmitted editors are not promised to survive quit.
5. Exercise failed replacement before first launch (for example, a denied copy to a test Applications folder). Check the previous intact app and complete library still work. An interrupted/partial copy must be repaired by reinstalling the trusted previous bundle before launch; Finder replacement is not claimed to be atomic.
6. Exercise migration failure and recovery on disposable copies, including pending-save review and originals. Run a previously signed compatible app after restoring the complete pre-update root; prove later/newer data remains separately recoverable. Test a too-new schema: the old app must visibly refuse, without overwriting anything.
7. Re-run Gatekeeper assessment, offline launch and byte checks on the exact final image. Keep last-known-good signed installers and version/hash evidence. No public release until launch is authorized.

There is no previous production signed release yet. Current same-schema/migration tests validate storage boundaries, and a disposable install-copy test validates packaging. Neither substitutes for a real signed binary update or clean-Mac execution.

## Library backup and rollback

The production store is the `ashique.nivlet.Nivlet` subdirectory of the sandbox app's Application Support directory. On the current sandboxed host this resolves under `~/Library/Containers/ashique.nivlet.Nivlet/Data/Library/Application Support/`. Verify the actual root for the installed version before copying. Do not confuse Debug development libraries with the production root. Never run a recovery operation against a live app.

Before updating, export all pockets, resolve save errors and quit through the menu bar. A portable archive includes selected live pockets and originals; it is not a complete backup of pending saves, trash or device preferences. Copy the **entire closed library root** to a private dated backup, including SQLite sidecars if present, `assets/`, staging/recovery files, archive leases and `snapshots/`. Keep device preferences separately if full shell restoration is needed. Do not copy only an open `library.sqlite`; SQLite transactions do not back up filesystem originals.

If the new binary has never launched and the library has not changed, reinstalling the last-known-good signed binary is normally sufficient. If it has launched or migrated:

1. Quit all copies. Preserve the entire failed/current root separately; keep any newer portable export too. Do not merge database files or discard a pending-save journal.
2. Reinstall the previous trusted signed app. Restore a complete **pre-update** library copy to its original location, with the app closed. Retain the failed/current root for later recovery. Avoid running an old binary on a newer schema; its refusal is intentional.
3. If only a pre-migration snapshot exists, work on a duplicate of the full failed/current root. Retain its originals and all other recovery material. In that duplicate only, remove the copied current `library.sqlite`, `library.sqlite-wal` and `library.sqlite-shm`, then copy the chosen `snapshots/library-vN-*.sqlite` as `library.sqlite`. The app must be closed throughout. The snapshot's metadata reflects its earlier point in time; later edits and pending saves may be absent. First validate with a compatible app in a disposable environment, never overwrite the only remaining copy.
4. Review recovered drafts explicitly and verify prompts, pockets, trash and every reference digest. Preserve backup/current copies until recovery is confirmed. Validated portable archives can be imported as new pockets into a supported version; they do not merge or silently replace existing content.

Schema 5 is unchanged in Phase 7. Existing migrations take consistent SQLite backup snapshots before transactionally migrating; retained originals make those snapshots useful. Future releases that change schemas must add forward-migration fixtures and test rollback using an actual previous binary before release.
