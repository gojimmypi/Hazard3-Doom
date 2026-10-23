#!/usr/bin/env python3
"""Compare two synthesized GateMate Yosys JSON netlists without changing them.

Usage:
    compare-ulx5m-btn2-netlists.py OLD.json FRESH.json

Identifies metadata-only, BRAM initialization, and structural differences.
"""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def is_bram(cell):
    return cell.get('type', '').startswith('CC_BRAM_')


def without_source_attributes(attributes):
    return {key: value for key, value in attributes.items() if key != 'src'}


def cell_for_comparison(cell, without_init=False):
    params = cell.get('parameters', {})
    if without_init and is_bram(cell):
        params = {key: value for key, value in params.items()
                  if not key.startswith('INIT_')}
    return {
        'type': cell.get('type'),
        'parameters': params,
        'connections': cell.get('connections'),
        'port_directions': cell.get('port_directions'),
        'attributes': without_source_attributes(cell.get('attributes', {})),
    }


def functional_view(design, without_init=False):
    result = {}
    for name, module in design['modules'].items():
        result[name] = {
            'ports': module.get('ports', {}),
            'attributes': without_source_attributes(module.get('attributes', {})),
            'cells': {key: cell_for_comparison(cell, without_init)
                      for key, cell in module.get('cells', {}).items()},
            'memories': module.get('memories', {}),
            'named_nets': {
                key: {**net, 'attributes': without_source_attributes(net.get('attributes', {}))}
                for key, net in module.get('netnames', {}).items()
                if not key.startswith('$')
            },
        }
    return result


def format_changes(counter_old, counter_new):
    differences = []
    for key in sorted(counter_old.keys() | counter_new.keys()):
        old, new = counter_old[key], counter_new[key]
        if old != new:
            differences.append(f'{key}: {old} -> {new}')
    return ', '.join(differences) if differences else 'identical'


def report_module(name, old, new):
    old_cells = old.get('cells', {})
    new_cells = new.get('cells', {})
    old_types = Counter(cell['type'] for cell in old_cells.values())
    new_types = Counter(cell['type'] for cell in new_cells.values())
    print(f'\nModule {name}:')
    print(f'  Cell totals: {len(old_cells)} -> {len(new_cells)}')
    print(f'  Cell-type differences: {format_changes(old_types, new_types)}')
    old_names = set(old_cells)
    new_names = set(new_cells)
    print(f'  Cell names: {len(old_names - new_names)} removed, '
          f'{len(new_names - old_names)} added')
    counters = Counter()
    examples = {}
    init_words = 0
    for cell_name in sorted(old_names & new_names):
        previous = old_cells[cell_name]
        current = new_cells[cell_name]
        if previous.get('type') != current.get('type'):
            category = 'type'
            counters[category] += 1
            examples.setdefault(category, cell_name)
            continue
        old_params = previous.get('parameters', {})
        new_params = current.get('parameters', {})
        init_keys = {key for key in old_params.keys() | new_params.keys()
                     if key.startswith('INIT_')}
        changed_init = sum(old_params.get(k) != new_params.get(k)
                           for k in init_keys)
        if changed_init:
            category = 'BRAM INIT cells' if is_bram(previous) else 'other INIT parameter cells'
            counters[category] += 1
            init_words += changed_init
            examples.setdefault(category, cell_name)
        if {k: v for k, v in old_params.items() if k not in init_keys} != \
           {k: v for k, v in new_params.items() if k not in init_keys}:
            counters['non-INIT parameters'] += 1
            examples.setdefault('non-INIT parameters', cell_name)
        if previous.get('connections') != current.get('connections'):
            counters['connections'] += 1
            examples.setdefault('connections', cell_name)
        if previous.get('port_directions') != current.get('port_directions'):
            counters['port directions'] += 1
            examples.setdefault('port directions', cell_name)
    for category in sorted(counters):
        print(f'  {category} differ: {counters[category]} '
              f'(example: {examples[category]})')
    if init_words:
        print(f'  Differing INIT_ fields: {init_words}')
    if old.get('ports', {}) != new.get('ports', {}):
        print('  Module port connections differ')
    if old.get('memories', {}) != new.get('memories', {}):
        print('  Module memories differ')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path, help='Frozen passing sweep design.json')
    parser.add_argument('fresh', type=Path, help='Fresh BTN2 synthesis JSON')
    parser.add_argument('--require-identical-logic', action='store_true',
                        help='Return nonzero if synthesized cell/port structure differs')
    args = parser.parse_args()
    for path in (args.reference, args.fresh):
        if not path.is_file():
            parser.error(f'File not found: {path}')
    try:
        with args.reference.open(encoding='utf-8') as source:
            old = json.load(source)
        with args.fresh.open(encoding='utf-8') as source:
            new = json.load(source)
    except (OSError, ValueError, UnicodeError) as exc:
        parser.error(str(exc))
    if not isinstance(old.get('modules'), dict) or not isinstance(new.get('modules'), dict):
        parser.error('Both inputs must be Yosys module-based JSON netlists')
    print('Reference:', args.reference)
    print('  SHA-256:', sha256(args.reference))
    print('  Creator: ', old.get('creator', '(missing)'))
    print('Fresh:    ', args.fresh)
    print('  SHA-256:', sha256(args.fresh))
    print('  Creator: ', new.get('creator', '(missing)'))
    old_modules = set(old['modules'])
    new_modules = set(new['modules'])
    print('\nModules:', len(old_modules), '->', len(new_modules))
    if old_modules != new_modules:
        print('  Missing:', ', '.join(sorted(old_modules - new_modules)) or '(none)')
        print('  Added:  ', ', '.join(sorted(new_modules - old_modules)) or '(none)')
    same_without_init = functional_view(old, True) == functional_view(new, True)
    same_with_init = functional_view(old) == functional_view(new)
    print('Logic/named-net structure excluding BRAM INIT: ',
          'SAME' if same_without_init else 'DIFFERENT')
    print('Logic/named-net structure including BRAM INIT: ',
          'SAME' if same_with_init else 'DIFFERENT')
    if same_with_init:
        print('Conclusion: Cell connections, ports, attributes, and named nets match; byte-level changes are metadata or serialization.')
    elif same_without_init:
        print('Conclusion: The only cell/port differences are BRAM INIT fields.')
        print('Check firmware and microcode HEX hashes before assuming RTL changed.')
    else:
        print('Conclusion: There are structural and/or non-BRAM-init differences.')
        print('Do not assume the previous seed 147 result applies to this netlist.')
    for name in sorted(old_modules & new_modules):
        a, b = old['modules'][name], new['modules'][name]
        if (a.get('cells', {}) != b.get('cells', {}) or
            a.get('ports', {}) != b.get('ports', {}) or
            a.get('memories', {}) != b.get('memories', {})):
            report_module(name, a, b)
    if args.require_identical_logic and not same_with_init:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
