#!/usr/bin/env python3
"""Prepare an Icarus-compatible copy of SERV 1.4.0's serv_state.v.

SERV references trap_pending before its declaration. Some Icarus versions
reject that reference. Move the declaration ahead of its first use in a
build-only copy without modifying the pinned upstream checkout.
"""

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: prepare-ulx5m-serv-iverilog.py INPUT OUTPUT", file=sys.stderr)
        return 2

    source = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    data = source.read_bytes()

    # Match the actual upstream source regardless of space/tab indentation.
    anchor_re = re.compile(rb"(?m)^([ \t]*)wire[ \t]+misalign_trap_sync[ \t]*;[ \t]*(\r?\n)")
    decl_re = re.compile(rb"(?m)^([ \t]*)wire[ \t]+trap_pending[ \t]*=")
    anchors = list(anchor_re.finditer(data))
    declarations = list(decl_re.finditer(data))
    first_use = data.find(b"!trap_pending")

    if (len(anchors) != 1 or len(declarations) != 1
            or first_use < 0 or not (anchors[0].start() < first_use < declarations[0].start())):
        raise SystemExit("ERROR: unexpected SERV serv_state.v; upstream may have changed")

    # Retain the original indentation and the entire trap_pending expression.
    indent = anchors[0].group(1)
    data = anchor_re.sub(lambda m: m.group(0) + indent + b"wire trap_pending;" + m.group(2), data, count=1)
    data, replaced = decl_re.subn(lambda m: m.group(1) + b"assign trap_pending =", data, count=1)
    if replaced != 1:
        raise SystemExit("ERROR: unable to rewrite SERV trap_pending assignment")

    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    print("[PASS] generated Icarus-compatible SERV state copy: " + str(dest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
