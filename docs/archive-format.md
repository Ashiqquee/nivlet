# Nivlet portable archive — format 1

30 October 2026 · [Phase 5 implementation and recovery](implementation/phase5-recovery.md)

A `.nivlet` file is an uncompressed, sequential container holding UTF-8 JSON metadata and exact original bytes. It is independent of SQLite schema 5. It is not ZIP/TAR, a database backup, a licence or a sync protocol. There is no encryption: treat the archive as private working material.

## Container

All lengths are unsigned 64-bit integers in network/big-endian byte order.

| Order | Bytes |
|---|---|
| Magic | Exactly eight ASCII bytes: `NIVLET01` |
| Manifest length | 8 bytes |
| Manifest | Exactly the declared number of UTF-8 JSON bytes |
| Asset entries | One per manifest asset, in the manifest array order |
| End | Must immediately follow the final entry; trailing data is rejected |

Each asset entry is one kind byte (only **0, regular file** is accepted), an 8-byte path length, the exact UTF-8 path bytes, an 8-byte payload length, then that many original bytes. Symlinks, hard-link/directory entry kinds, compression and unknown kinds are unsupported and refused. Entry path/size must exactly match its manifest entry. Duplicate entries, out-of-order/repeated paths, truncation and trailing data fail validation.

There is no decompressor and therefore no compressed expansion. Both declared and actual extents are bounded. ZIP/TAR and compressed bombs fail the magic check; spoofed oversized entries fail bounds or exact framing before they can be accepted.

## Manifest

Top-level required fields are `formatVersion: 1`, `pockets: [...]` and `assets: [...]`.

| Record | Required fields |
|---|---|
| Pocket | `id` UUID, `name`, ordered `prompts`, ordered `references`, exact `scratchpad` string |
| Prompt | `id` UUID, `label`, exact `source`, `isFavorite` Boolean, `usesFields` Boolean |
| Reference | `id` UUID, `label`, exact `note`, independent `displayName`, `digest`, `isFavorite` Boolean |
| Asset | `digest` lowercase 64-character SHA-256, `byteCount` unsigned integer, `archivePath` |

The only valid asset path is `assets/<digest>/original`. The digest is of the exact original byte sequence. Every asset must be referenced, every reference must name an included asset, asset digests must be unique, pocket IDs must be unique, and prompt/reference IDs must be globally unique across items. Names/labels and prompt sources must be nonblank. Named-blank sources must pass the shared template parser. Strings preserve Unicode, whitespace and CR/LF/CRLF exactly.

`displayName` is metadata. It is never interpreted as an extraction path. Restore writes to app-generated UUID staging folders and digest filenames, not supplied archive paths. On commit, the app derives the image flag from the verified bytes. Outgoing reference transfers still use the existing safe-filename policy.

Array order is the portable order; favourites are independent flags. Identical original bytes deduplicate while per-reference display names/labels/notes stay independent. Restore generates new pocket and item IDs on every accepted import, appends pockets to the destination and keeps the destination's active pocket. Restoring the same archive again creates additional independent pockets, with no implicit merge/overwrite.

Excluded: trash, current pocket/view/search/scroll bookmarks, unsubmitted editor drafts, filled values, entitlement/licences/issuer secrets, machine/display/shortcut preferences, thumbnails, staged operations, transfer copies and diagnostic logs. Export one pocket or all **live** pockets. An export preview freezes a metadata snapshot and pins its original bytes until completion/cancellation.

## Format 1 bounds

| Limit | Current bound |
|---|---|
| Manifest | 16 MiB |
| One original | 2,000,000,000 bytes |
| All original payloads | 20,000,000,000 bytes |
| Distinct assets | 20,000 |
| Pockets | 2,000 |
| Total prompt/reference items | 100,000 |
| Encoded entry path | 128 bytes |
| Streaming buffer | At most 1 MiB per copy/hash chunk |

The parser checks overflow before addition and rejects unsupported versions. These are conservative current implementation bounds, not measured maximum-size performance promises. Space is checked before staging/writing; a later disk-full error still aborts safely. Files are synchronised before placement/publication; export uses a Foundation-managed same-volume replacement directory for sandbox-selected destinations. Restores validate all bytes before preview and recheck originals at commit. Only the final metadata transaction makes pockets visible; failed restores do not journal an unaccepted destination snapshot.

## Disposable fixtures

The repository script uses only Python's standard library and synthetic content:

```sh
python3 scripts/make_archive_fixture.py /tmp/nivlet-example.nivlet
python3 scripts/make_archive_fixture.py /tmp/nivlet-invalid.nivlet --corrupt
```

It refuses to overwrite an existing file. The valid fixture contains one pocket, a plain and a named-blank prompt, a checklist and one original reference. The invalid fixture changes an original byte without changing its digest. Unit tests generate additional disposable multi-pocket and hostile fixtures under unique temporary roots; no working private library is used.
