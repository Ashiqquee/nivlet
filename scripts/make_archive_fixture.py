#!/usr/bin/env python3
"""Create a tiny, deterministic synthetic Nivlet archive (no private data)."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def fixture(corrupt=False):
    original = 'Original reference bytes ✅\r\n'.encode()
    digest = hashlib.sha256(original).hexdigest()
    asset = {'digest': digest, 'byteCount': len(original), 'archivePath': f'assets/{digest}/original'}
    manifest = {'formatVersion': 1, 'pockets': [{
        'id': '10000000-0000-0000-0000-000000000001', 'name': 'Example kit',
        'prompts': [
            {'id': '20000000-0000-0000-0000-000000000001', 'label': 'Writing style',
             'source': 'Keep the meaning and my voice.\r\nShow the revised text first. ✅', 'isFavorite': True, 'usesFields': False},
            {'id': '20000000-0000-0000-0000-000000000002', 'label': 'Review a page',
             'source': 'Review {{page}} for {{audience}}. Keep {{page}} specific.', 'isFavorite': False, 'usesFields': True}],
        'references': [{'id': '30000000-0000-0000-0000-000000000001', 'label': 'Layout reference',
                        'note': 'A synthetic original for recovery checks.', 'displayName': 'Layout reference.txt',
                        'digest': digest, 'isFavorite': False}],
        'scratchpad': '[x] Export the kit ✅\n[ ] Restore into a disposable library\n'}], 'assets': [asset]}
    metadata = json.dumps(manifest, ensure_ascii=False, separators=(',', ':')).encode()
    path = asset['archivePath'].encode()
    content = bytearray(original)
    if corrupt:
        content[0] ^= 255
    archive = b'NIVLET01' + struct.pack('>Q', len(metadata)) + metadata
    archive += b'\0' + struct.pack('>Q', len(path)) + path + struct.pack('>Q', len(content)) + content
    return archive


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--corrupt', action='store_true', help='Write a deliberate digest mismatch for refusal checks.')
    args = parser.parse_args()
    # Refuse to overwrite an existing file; fixtures should be disposable.
    with args.output.open('xb') as output:
        output.write(fixture(args.corrupt))
    print(f'Created synthetic {"invalid" if args.corrupt else "valid"} archive: {args.output.name}')
