#!/usr/bin/env python3
"""Read-only qualification of a v48 CI seed-10 group and frozen netlist.

This validates reported routing/packaging evidence, not SPI-active takeover.
It never invokes any FPGA, USB, SPI, JTAG, or flash operation.
"""
import argparse
import csv
import hashlib
import importlib.util
import re
from pathlib import Path

SEED = 10
FMIN = 48.0
TARGET = "spi-secondary"
BOOTADDR = "0x201000"
FMAX_RE = re.compile(r"Max frequency for clock 'bram_i\.clk': ([0-9]+\.[0-9]+) MHz \((PASS|FAIL) at 48\.00 MHz\)")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path):
    return dict(line.split("=", 1) for line in path.read_text(encoding="ascii").splitlines() if "=" in line)


def validate(group, frozen, inspector):
    group, frozen = Path(group), Path(frozen)
    with (group / "results.tsv").open(encoding="ascii") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    matches = [r for r in rows if r["seed"] == str(SEED)]
    if len(matches) != 1:
        raise ValueError("expected exactly one seed-10 result")
    row = matches[0]
    if row["status"] != "PASS" or row["exit_code"] != "0":
        raise ValueError("seed 10 is not a completed PASS")
    fmax = float(row["fmax_mhz"])
    if fmax < FMIN or abs(float(row["margin_mhz"]) - (fmax - FMIN)) > .011:
        raise ValueError("fmax/margin invalid")
    log = (group / "seed-10.log").read_text(encoding="utf-8", errors="replace")
    timing = FMAX_RE.findall(log)
    if not timing or timing[-1][1] != "PASS" or abs(float(timing[-1][0]) - fmax) > .011:
        raise ValueError("final routed clock does not match results.tsv PASS")
    if "Routing complete." not in log:
        raise ValueError("route completion absent")
    info = metadata(group / "build-info.txt")
    if info.get("target") != TARGET or info.get("bootaddr") != BOOTADDR:
        raise ValueError("wrong group target/boot address")
    frozen_info = metadata(frozen / "metadata.txt")
    if frozen_info.get("target") != TARGET or frozen_info.get("gmpack_bootaddr") != BOOTADDR:
        raise ValueError("wrong frozen design/boot address")
    if info.get("commit") != frozen_info.get("commit") or not info.get("commit"):
        raise ValueError("mixed sweep commits")
    actual_netlist = sha256(frozen / "netlist.json")
    if actual_netlist != info.get("netlist_sha256") or actual_netlist != frozen_info.get("netlist_sha256"):
        raise ValueError("CI route does not match frozen synthesis netlist")
    pinned = (frozen / "SHA256SUMS").read_text(encoding="ascii").splitlines()
    expected_files = {"netlist.json", "constraints.ccf", "constraints.sdc"}
    verified = set()
    for line in pinned:
        digest, filename = line.split(None, 1)
        filename = filename.lstrip("* ")
        if filename not in expected_files or sha256(frozen / filename) != digest:
            raise ValueError("frozen input hash failure: " + filename)
        verified.add(filename)
    if verified != expected_files:
        raise ValueError("incomplete frozen input hashes")
    # Check that the route group actually used all three frozen inputs.
    route_inputs = (group / "inputs.sha256").read_text(encoding="ascii").splitlines()
    actual_route_inputs = {}
    for line in route_inputs:
        digest, filename = line.split(None, 1)
        filename = Path(filename.lstrip("* ")).name
        if filename in actual_route_inputs or filename not in expected_files:
            raise ValueError("invalid group inputs.sha256 entry")
        actual_route_inputs[filename] = digest
    if actual_route_inputs != {name: sha256(frozen / name) for name in expected_files}:
        raise ValueError("route group did not use the frozen inputs")
    # Per-job best may be a different seed if another PASS was faster.
    candidates = [group / "seed-10.bit", group / "best-seed-10.bit"]
    bits = [p for p in candidates if p.is_file()]
    if not bits:
        raise ValueError("seed-10 bitstream absent; rerun only seed 10 with retain_bitstreams=true")
    if len(bits) > 1 and sha256(bits[0]) != sha256(bits[1]):
        raise ValueError("seed-10 bitstream copies differ")
    spec = importlib.util.spec_from_file_location("v47_inspect", str(inspector))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    size, digest = module.inspect(bits[0])
    return {"seed": SEED, "fmax_mhz": fmax, "primary_bytes": size,
            "primary_sha256": digest, "netlist_sha256": actual_netlist,
            "bitstream": str(bits[0])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", type=Path, required=True, help="CI group-results directory containing seed 10")
    parser.add_argument("--frozen", type=Path, required=True, help="CI frozen/ directory from the same run")
    args = parser.parse_args()
    inspector = Path(__file__).resolve().with_name("inspect-ulx5m-v47-primary.py")
    try:
        result = validate(args.group, args.frozen, inspector)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, "[FAIL] " + str(error) + "\n")
    print("[PASS] seed 10: matching netlist, completed route, 48 MHz timing and bootaddr trailer")
    for field, value in result.items():
        print(field + ":", value)
    print("[NOT VERIFIED] SPI-active takeover, BTN2 recovery, flash-zero stage0")


if __name__ == "__main__":
    main()
