#!/usr/bin/env python3
"""Check actual selected PNG dimensions/counts; never generate or stretch captures."""
import argparse
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def png_size(path: Path) -> tuple[int, int]:
    with path.open('rb') as handle:
        header = handle.read(33)
    if len(header) < 33 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
        raise ValueError(f'Not a PNG: {path}')
    return struct.unpack('>II', header[16:24])


def inspect(directory: Path, specification: dict) -> list[str]:
    errors = []
    for name, group in specification['groups'].items():
        files = sorted((directory / name).glob('*.png'))
        if group['required'] and not files:
            errors.append(f'Missing actual screenshots: {name}')
        if len(files) > 10:
            errors.append(f'{name}: choose at most 10 screenshots')
        allowed = {tuple(size) for size in group['portrait_sizes']}
        allowed |= {(height, width) for width, height in allowed}
        for path in files:
            try:
                size = png_size(path)
                if size not in allowed:
                    errors.append(f'{path}: {size} is not an accepted size for {name}')
            except (OSError, ValueError, struct.error) as error:
                errors.append(str(error))
    return errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, nargs='?', default=ROOT / '.release/screenshots')
    args = parser.parse_args()
    errors = inspect(args.directory, json.loads((ROOT / 'appstore/screenshots.json').read_text()))
    if errors:
        raise SystemExit('\n'.join(errors))
    print('PNG dimensions/counts passed. Human review must confirm real UI, accurate claims, no private data and no unwanted transparency.')
