# Phase 8 release review

Prepared 31 October 2026 · **Incomplete; no publication or outreach authorized**

[Phase 8 evidence](../implementation/phase8-release.md) · [Distribution](../distribution.md) · [Study kit](../validation/README.md)

## Candidate binding

For each check record date, tester, exact version/build, source commit/clean state, executable and final DMG SHA-256, environment, method, result and evidence path. A pass on an old/local/debug build is not a pass on a new signed candidate. Retain failed attempts. Never put credentials, private libraries or participant records in this packet.

| Gate | State | Required evidence |
|---|---|---|
| AC-01 shell | Open | Final focus/click-away, Spaces, wake, display detach/reconnect; documented full-screen limits |
| AC-02 plain prompts | Partial local evidence | Final release mouse/keyboard/VoiceOver and exact reviewed copy checks |
| AC-03 templates | Partial local evidence | Final native fill/reset/edit-warning flow and exact preview/copy |
| AC-04 files | Open | 20 mixed originals offline/relaunch/export plus exact destination/browser versions and fallback results |
| AC-05 pockets | Partial local evidence | Final native ownership/search/move/Undo and immediate quit/relaunch |
| AC-06 recovery | Local Phase 5 gate passed | Reconfirm restore, migration failure and complete-library rollback for final candidate |
| AC-07 entitlement | Retired | Free app; no purchase or activation |
| AC-08 accessibility | Open | Spoken VoiceOver, complete keyboard flow, supported text/appearance/motion settings |
| Developer ID / Hardened Runtime / entitlements | Open | Actual final signature, intended team and bundle identity |
| Notarization and app/image stapling | Open | Accepted submission reports and ticket validation after final packaging |
| Clean-Mac and offline first launch | Open | Quarantine-preserving download, no warmed trust cache, final hashes |
| Real signed update and rollback | Open | Previous/new exact binaries, originals/container continuity and retained backup recovery |
| Supported configuration list | Open | Tested runtimes/hardware/displays; no inference from deployment target |
| Study and decision | Not observed | Anonymized consent-based eight-person and seven-day report |
| Footage/screenshots | Preparation | Real app sample captures with hashes/provenance; recheck against final release |
| Website/policies/support | Draft | Reviewed content, verified support/contact and hosting/privacy terms |
| Price and contributions | Resolved scope | Free; optional coffee; no trial/checkout/activation copy |
| Release contents | Open | Final package scan: no private data, secrets or third-party reference artwork |
| Download integrity | Open | Exact final version/build, image SHA-256, size and HTTPS destination; compare after download |
| Rollback | Open | Retained trusted installer, website version, withdrawal and data recovery procedure |
| Publication | Not performed | Specific owner-approved version, URL/audience, download and policies |

## Reviewable publication request

Prepare the final candidate manifest and checklist above first. Present the exact website revision/preview, intended public URL, version/build/checksum, support/policy text, technical evidence, validation decision, known limitations and rollback route together. Then obtain authorization for the specific publication action. Signing submission and tester outreach are separate external actions; preparing this packet does not perform them.

## After authorized publication

Download through the actual public link, compare final bytes/checksum, verify trust and a clean install/first run, inspect every policy/support link, and repeat the release journey without a developer session. There is no purchase/activation journey. Record actual hosting URL, deployment identifier, timestamp and result. A failed install or data-loss report triggers withdrawal of the download and preservation of affected recoverable state; do not overwrite the only library copy.

For website rollback, restore the retained reviewed source/deployment and remove the withdrawn download link. For the app, offer only a trusted compatible previous installer; on the first release there may be none. In that case withdraw the download and provide recovery guidance without inventing a previous version. Keep exports/full closed-library backups separate from installer rollback.
