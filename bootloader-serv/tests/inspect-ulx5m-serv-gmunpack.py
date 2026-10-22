#!/usr/bin/env python3
"""Test verified factory flash against Project Peppercorn gmunpack, offline.

Parser acceptance is format evidence only, never flash-write authorization.
No JTAG, USB, erase, or program operations are performed by this tool.
"""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

FLASH_BYTES = 4 * 1024 * 1024
SECTOR_BYTES = 4096
GATEMATE_SYNC = bytes.fromhex("d9 01 ed 96")
PARSER_TIMEOUT_SECONDS = 120
PLL_PAYLOAD_BYTES = 24
PLL_PAD_BYTES = 12
PLL_COMPAT_PAD_BYTES = 8


def crc16_x25(data):
    """GateMate command CRC16/X-25, as stored little-endian in bitstreams."""
    crc = 0xffff
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0x8408 if crc & 1 else 0)
    return crc ^ 0xffff


def trim_pll_padding_for_parser(binary, keep_pad_bytes=PLL_COMPAT_PAD_BYTES):
    """Return a temporary analysis copy with verified C1 padding shortened.

    Do not use this derived byte stream for FPGA programming or boot images.
    Only trim CRC-valid 24-byte PLL commands with exactly 12 padding NOPs
    followed by a command with a valid header CRC.
    """
    if keep_pad_bytes not in (8, 6, 4, 0):
        raise ValueError("PLL parser probe requires 8, 6, 4, or 0 padding bytes")
    offsets = []
    cursor = 0
    output = bytearray()
    frame_bytes = 4 + PLL_PAYLOAD_BYTES + 2
    while True:
        offset = binary.find(b"\xc1\x18", cursor)
        if offset < 0:
            output.extend(binary[cursor:])
            break
        output.extend(binary[cursor:offset])
        end = offset + frame_bytes
        next_command = end + PLL_PAD_BYTES
        valid = (next_command + 4 <= len(binary) and
                 crc16_x25(binary[offset:offset + 2]) ==
                 int.from_bytes(binary[offset + 2:offset + 4], "little") and
                 crc16_x25(binary[offset:end - 2]) ==
                 int.from_bytes(binary[end - 2:end], "little") and
                 binary[end:next_command] == bytes(PLL_PAD_BYTES) and
                 0xc0 <= binary[next_command] <= 0xdf and
                 crc16_x25(binary[next_command:next_command + 2]) ==
                 int.from_bytes(binary[next_command + 2:next_command + 4], "little"))
        if valid:
            output.extend(binary[offset:end + keep_pad_bytes])
            offsets.append(offset)
            cursor = next_command
        else:
            output.extend(binary[offset:offset + 2])
            cursor = offset + 2
    return bytes(output), offsets


def file_digest(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def load_verified_flash(source):
    path = Path(__file__).resolve().with_name("inspect-ulx5m-serv-factory-config.py")
    spec = importlib.util.spec_from_file_location("ulx5m_factory_inspection", path)
    if spec is None or spec.loader is None:
        raise ValueError("Cannot load factory backup verification module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.load_verified_backup(source)


def input_variants(flash):
    if len(flash) != FLASH_BYTES or not flash.startswith(GATEMATE_SYNC):
        raise ValueError("Expected verified GateMate flash with 4 MiB capacity")
    prefix_bytes = len(flash.rstrip(b"\xff"))
    if prefix_bytes == 0:
        raise ValueError("Flash appears fully erased")
    aligned_bytes = min(FLASH_BYTES, (
        (prefix_bytes + SECTOR_BYTES - 1) // SECTOR_BYTES) * SECTOR_BYTES)
    return {
        "observed_prefix": flash[:prefix_bytes],
        "sector_aligned_prefix": flash[:aligned_bytes],
        "complete_flash": flash,
    }


def locate_gmunpack(value):
    if value:
        binary = Path(value)
        if not binary.is_file():
            raise ValueError("gmunpack executable does not exist: " + value)
        return str(binary.resolve())
    binary = shutil.which("gmunpack")
    if not binary:
        raise ValueError("gmunpack not found on PATH (install an OSS CAD Suite build with gmunpack)")
    return binary


def unpack_one(gmunpack, label, binary, workspace, keep_dir=None, timeout=PARSER_TIMEOUT_SECONDS):
    input_path = workspace / (label + ".bit")
    output_path = workspace / (label + ".config")
    log_path = workspace / (label + ".log")
    input_path.write_bytes(binary)
    result = {
        "input_bytes": len(binary),
        "input_sha256": hashlib.sha256(binary).hexdigest(),
        "returncode": None,
        "parser_succeeded": False,
        "config_bytes": 0,
        "config_sha256": None,
        "diagnostic": "",
    }
    # gmunpack accepts input.bit [output.config]; keep all intermediate files
    # inside a temporary directory unless --output-dir was explicitly supplied.
    with log_path.open("wb") as log:
        try:
            process = subprocess.run([gmunpack, str(input_path), str(output_path)],
                                     cwd=str(workspace), stdout=log, stderr=subprocess.STDOUT,
                                     check=False, timeout=timeout)
            result["returncode"] = process.returncode
        except subprocess.TimeoutExpired:
            result["diagnostic"] = "gmunpack timed out"
        except OSError as exc:
            result["diagnostic"] = "Could not execute gmunpack: " + str(exc)
    if log_path.exists():
        with log_path.open("rb") as log:
            result["log_excerpt"] = log.read(1000).decode("utf-8", errors="replace")
    if output_path.is_file():
        result["config_bytes"] = output_path.stat().st_size
        result["config_sha256"] = file_digest(output_path)
    result["parser_succeeded"] = (result["returncode"] == 0 and
                                  result["config_bytes"] > 0)
    if keep_dir is not None and result["config_bytes"] > 0:
        # Create files only in a newly created, explicitly requested directory.
        shutil.copyfile(output_path, keep_dir / (label + ".config"))
    return result


def inspect(source, reference_path, gmunpack, output_dir=None, json_out=None,
            timeout=PARSER_TIMEOUT_SECONDS, pll_padding_compat=False,
            pll_padding_probe=False):
    if output_dir is not None and output_dir.exists():
        raise ValueError("Refusing to use an existing output directory: " + str(output_dir))
    if json_out is not None and json_out.exists():
        raise ValueError("Refusing to overwrite report: " + str(json_out))
    if pll_padding_compat and pll_padding_probe:
        raise ValueError("Use only one PLL compatibility option")
    flash = load_verified_flash(source)
    reference = reference_path.read_bytes()
    if len(reference) < 16 or not reference.startswith(GATEMATE_SYNC):
        raise ValueError("Reference bitstream lacks the GateMate signature")
    variants = input_variants(flash)
    result = {
        "format": "ULX5M-GS gmunpack inspection v1",
        "verified_flash_sha256": hashlib.sha256(flash).hexdigest(),
        "verified_flash_bytes": len(flash),
        "observed_prefix_bytes": len(variants["observed_prefix"]),
        "first_all_ff_sector": len(variants["sector_aligned_prefix"]),
        "reference_is_factory_image": False,
        "parser": gmunpack,
        "reference": None,
        "factory_attempts": {},
        "pll_padding_compat_requested": pll_padding_compat,
        "pll_padding_probe_requested": pll_padding_probe,
        "pll_padding_compat_used": False,
        "pll_padding_kept_bytes": None,
        "reference_probes": [],
        "reference_original": None,
        "reference_pll_offsets": [],
        "factory_stream_end_verified": False,
        "secondary_boot_layout_verified": False,
        "write_authorized": False,
    }
    with tempfile.TemporaryDirectory(prefix="ulx5m-gmunpack-") as dirname:
        workspace = Path(dirname)
        # Check gmunpack against a real, known gmpack output before drawing any
        # conclusion about factory-image errors or success.
        reference_result = unpack_one(gmunpack, "known_serv_reference", reference,
                                      workspace, None, timeout)
        if not reference_result["parser_succeeded"] and (pll_padding_compat or pll_padding_probe):
            result["reference_original"] = reference_result
            choices = (8, 6, 4, 0) if pll_padding_probe else (8,)
            for keep_bytes in choices:
                compatible_reference, offsets = trim_pll_padding_for_parser(
                    reference, keep_pad_bytes=keep_bytes)
                if not offsets:
                    raise ValueError("No CRC-verified 12-byte PLL padding to adjust "
                                     "in the reference; original parser error: " +
                                     reference_result.get("log_excerpt", "")[:250])
                attempt = unpack_one(gmunpack, "known_serv_reference_pll_keep%d" % keep_bytes,
                                     compatible_reference, workspace, None, timeout)
                result["reference_probes"].append({
                    "kept_padding_bytes": keep_bytes,
                    "result": attempt,
                })
                reference_result = attempt
                if attempt["parser_succeeded"]:
                    result["reference_pll_offsets"] = offsets
                    result["pll_padding_kept_bytes"] = keep_bytes
                    result["pll_padding_compat_used"] = True
                    break
        result["reference"] = reference_result
        if not reference_result["parser_succeeded"]:
            probes = "; ".join(
                "keep%d: exit=%s %s" % (
                    p["kept_padding_bytes"], p["result"]["returncode"],
                    p["result"].get("log_excerpt", "").strip()[-180:])
                for p in result["reference_probes"])
            raise ValueError("gmunpack cannot decode the known SERV reference; "
                             "factory validation not attempted: " +
                             (probes if probes else
                              reference_result.get("log_excerpt", "")[:250]))
        if output_dir is not None:
            output_dir.mkdir(parents=False, exist_ok=False)
        for label, content in variants.items():
            original_sha = hashlib.sha256(content).hexdigest()
            offsets = []
            if result["pll_padding_compat_used"]:
                content, offsets = trim_pll_padding_for_parser(
                    content, keep_pad_bytes=result["pll_padding_kept_bytes"])
            attempt = unpack_one(gmunpack, label, content, workspace, output_dir, timeout)
            attempt["original_input_sha256"] = original_sha
            attempt["pll_padding_offsets"] = offsets
            result["factory_attempts"][label] = attempt
    if json_out is not None:
        with json_out.open("x", encoding="utf-8", newline="\n") as report:
            json.dump(result, report, indent=2, sort_keys=True)
            report.write("\n")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True,
                        help="Verified two-pass flash backup directory or ZIP")
    parser.add_argument("--reference-bit", type=Path, required=True,
                        help="Known-good gmpack-generated SERV .bit file")
    parser.add_argument("--gmunpack", help="Path to gmunpack; defaults to PATH")
    parser.add_argument("--pll-padding-compat", action="store_true",
                        help="Opt-in: retry a failed reference with 12-to-8 PLL "
                             "padding in temporary parser inputs")
    parser.add_argument("--pll-padding-probe", action="store_true",
                        help="Opt-in: test 12-to-8, 12-to-6, 12-to-4, then 12-to-0 "
                             "CRC-verified PLL padding against the known reference")
    parser.add_argument("--output-dir", type=Path,
                        help="New directory in which to retain text configurations")
    parser.add_argument("--json-out", type=Path,
                        help="Create a new JSON report (never overwrite)")
    args = parser.parse_args(argv)
    try:
        result = inspect(args.input, args.reference_bit,
                         locate_gmunpack(args.gmunpack), args.output_dir, args.json_out,
                         pll_padding_compat=args.pll_padding_compat,
                         pll_padding_probe=args.pll_padding_probe)
        print("[PASS] Verified flash SHA-256 " + result["verified_flash_sha256"])
        print("[REFERENCE] known SERV bitstream decoded; %d config bytes" %
              result["reference"]["config_bytes"])
        if result["pll_padding_compat_used"]:
            print("[COMPAT] Temporary reference copy: kept %d of 12 NOP bytes "
                  "in each of %d CRC-verified PLL commands" % (
                  result["pll_padding_kept_bytes"],
                  len(result["reference_pll_offsets"])))
        for probe in result["reference_probes"]:
            print("[PROBE] PLL pad=%d: exit=%s, output=%d bytes" % (
                probe["kept_padding_bytes"], probe["result"]["returncode"],
                probe["result"]["config_bytes"]))
        for name, attempt in result["factory_attempts"].items():
            print("[FACTORY] %s: %d input bytes, %s (exit=%s, text=%d bytes)" % (
                name, attempt["input_bytes"],
                "DECODED" if attempt["parser_succeeded"] else "REJECTED",
                attempt["returncode"], attempt["config_bytes"]))
        if args.json_out is not None:
            print("[REPORT] " + str(args.json_out))
        if args.output_dir is not None:
            print("[TEXT CONFIGS] " + str(args.output_dir))
        print("[POLICY] Parser results do not establish configuration boundaries "
              "or authorize flash writes")
        return 0 if any(x["parser_succeeded"] for x in
                        result["factory_attempts"].values()) else 1
    except (OSError, ValueError, RuntimeError, ImportError, KeyError) as exc:
        print("[FAIL] " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
