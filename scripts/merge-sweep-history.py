#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Merge per-run sweep performance CSVs, deduplicating run attempts."""
import argparse
import csv
from pathlib import Path


def merge(paths, output):
    columns = []
    rows = {}
    for path in paths:
        with path.open(newline='', encoding='utf-8') as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames or not {'run_id', 'run_attempt', 'board'} <= set(reader.fieldnames):
                raise ValueError(f'{path}: invalid history schema')
            for name in reader.fieldnames:
                if name not in columns:
                    columns.append(name)
            for row in reader:
                key = (row['run_id'], row['run_attempt'], row['board'])
                if not all(key):
                    raise ValueError(f'{path}: missing run identity')
                rows[key] = row
    with output.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(sorted(rows.values(), key=lambda row: (int(row['run_id']), int(row['run_attempt']), row['board'])))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('inputs', nargs='+', type=Path)
    args = parser.parse_args()
    merge(args.inputs, args.output)
