#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import serial
except ImportError as exc:
    raise SystemExit("pyserial is required: python3 -m pip install pyserial") from exc

TICKS_RE = re.compile(r"^Total ticks\s*:\s*(\d+)\s*$")
ITERATIONS_RE = re.compile(r"^Iterations\s*:\s*(\d+)\s*$")
HAZARD_CYCLES_RE = re.compile(r"^\s*cycles\s*=\s*(\d+)\s*$")
HAZARD_INSTRUCTIONS_RE = re.compile(r"^\s*instructions\s*=\s*(\d+)\s*$")
ISA_RE = re.compile(
    r"^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*(yes|no|not-enumerated|unknown)(?:\s*;.*)?\s*$"
)
MISA_RE = re.compile(r"^Hazard3 ISA:\s+misa\s*=\s*(0x[0-9a-fA-F]+)\s*$")
H3_BITMAP_LENGTH_RE = re.compile(r"^\s*h3\.misa bitmap length\s*=\s*(\d+) bits\s*$")
H3_BITMAP_WORD_RE = re.compile(r"^\s*h3\.misa\[(\d+)\]\s*=\s*(0x[0-9a-fA-F]+)\s*$")

# Current standard-extension bit assignments from the RISC-V C API extension
# bitmask. Hazard3 h3.misa uses these same group/bit assignments.
C_API_EXTENSIONS = [
    ("A", 0, 0, "atomic instructions"),
    ("B", 0, 1, "bit manipulation"),
    ("C", 0, 2, "compressed instructions"),
    ("D", 0, 3, "double-precision floating point"),
    ("E", 0, 4, "reduced integer register set"),
    ("F", 0, 5, "single-precision floating point"),
    ("H", 0, 7, "hypervisor"),
    ("I", 0, 8, "base integer ISA"),
    ("M", 0, 12, "integer multiply/divide"),
    ("Q", 0, 16, "quad-precision floating point"),
    ("V", 0, 21, "vector"),
    ("Zacas", 0, 26, "compare-and-swap atomics"),
    ("Zba", 0, 27, "address generation"),
    ("Zbb", 0, 28, "basic bit manipulation"),
    ("Zbc", 0, 29, "carry-less multiplication"),
    ("Zbkb", 0, 30, "basic bit manipulation for scalar cryptography"),
    ("Zbkc", 0, 31, "carry-less multiplication for scalar cryptography"),
    ("Zbkx", 0, 32, "crossbar permutation instructions"),
    ("Zbs", 0, 33, "single-bit manipulation"),
    ("Zfa", 0, 34, "additional floating-point instructions"),
    ("Zfh", 0, 35, "half-precision floating point"),
    ("Zfhmin", 0, 36, "minimal half-precision floating point"),
    ("Zicboz", 0, 37, "cache-block zero"),
    ("Zicond", 0, 38, "integer conditional operations"),
    ("Zihintntl", 0, 39, "non-temporal locality hints"),
    ("Zihintpause", 0, 40, "pause hint"),
    ("Zknd", 0, 41, "NIST AES decryption"),
    ("Zkne", 0, 42, "NIST AES encryption"),
    ("Zknh", 0, 43, "NIST hash functions"),
    ("Zksed", 0, 44, "ShangMi block cipher"),
    ("Zksh", 0, 45, "ShangMi hash"),
    ("Zkt", 0, 46, "data-independent execution latency"),
    ("Ztso", 0, 47, "total store ordering"),
    ("Zvbb", 0, 48, "vector basic bit manipulation"),
    ("Zvbc", 0, 49, "vector carry-less multiplication"),
    ("Zvfh", 0, 50, "vector half-precision floating point"),
    ("Zvfhmin", 0, 51, "minimal vector half-precision floating point"),
    ("Zvkb", 0, 52, "vector cryptography bit manipulation"),
    ("Zvkg", 0, 53, "vector GCM/GMAC"),
    ("Zvkned", 0, 54, "vector NIST AES"),
    ("Zvknha", 0, 55, "vector SHA-2 SHA-256"),
    ("Zvknhb", 0, 56, "vector SHA-2 SHA-512"),
    ("Zvksed", 0, 57, "vector ShangMi block cipher"),
    ("Zvksh", 0, 58, "vector ShangMi hash"),
    ("Zvkt", 0, 59, "vector data-independent execution latency"),
    ("Zve32x", 0, 60, "embedded vector 32-bit integer"),
    ("Zve32f", 0, 61, "embedded vector 32-bit floating point"),
    ("Zve64x", 0, 62, "embedded vector 64-bit integer"),
    ("Zve64f", 0, 63, "embedded vector 64-bit floating point"),
    ("Zve64d", 1, 0, "embedded vector 64-bit double precision"),
    ("Zimop", 1, 1, "may-be-operations"),
    ("Zca", 1, 2, "base compressed instruction subset"),
    ("Zcb", 1, 3, "basic additional compressed instructions"),
    ("Zcd", 1, 4, "compressed double-precision loads/stores"),
    ("Zcf", 1, 5, "compressed single-precision loads/stores"),
    ("Zcmop", 1, 6, "compressed may-be-operations"),
    ("Zawrs", 1, 7, "wait-on-reservation-set"),
    ("Zilsd", 1, 8, "load/store pair instructions"),
    ("Zclsd", 1, 9, "compressed load/store pair instructions"),
    ("Zcmp", 1, 10, "push/pop and double-move instructions"),
    ("Zifencei", 1, 11, "instruction-fetch fence"),
    ("Zmmul", 1, 12, "integer multiplication subset of M"),
    ("Zibi", 1, 13, "integer branch immediate"),
    ("Supm", 1, 14, "pointer masking"),
    ("Zicntr", 1, 15, "cycle/time/instret counters"),
    ("Zihpm", 1, 16, "hardware performance counters"),
    ("Zfbfmin", 1, 17, "scalar BF16 conversion"),
    ("Zvfbfmin", 1, 18, "vector BF16 conversion"),
    ("Zvfbfwma", 1, 19, "vector BF16 widening multiply-add"),
    ("Zicbom", 1, 20, "cache-block management"),
    ("Zaamo", 1, 21, "atomic memory operations subset of A"),
    ("Zalrsc", 1, 22, "load-reserved/store-conditional subset of A"),
    ("Zabha", 1, 23, "byte and halfword atomics"),
    ("Zalasr", 1, 24, "load-acquire/store-release"),
    ("Zicbop", 1, 25, "cache-block prefetch"),
    ("Zicfilp", 1, 26, "landing-pad control-flow integrity"),
    ("Zicfiss", 1, 27, "shadow-stack control-flow integrity"),
]

HAZARD3_C_API_EXTENSIONS = {
    "A", "B", "C", "E", "I", "M",
    "Zba", "Zbb", "Zbc", "Zbkb", "Zbkc", "Zbkx", "Zbs", "Zkt",
    "Zca", "Zcb", "Zilsd", "Zclsd", "Zcmp", "Zifencei", "Zmmul",
    "Zicntr", "Zaamo", "Zalrsc",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Load and capture Hazard3 ULX3S CoreMark")
    parser.add_argument("--elf", required=True, type=Path)
    parser.add_argument("--port", required=True)
    parser.add_argument("--loader", required=True, type=Path)
    parser.add_argument("--clock-hz", type=int, default=50_000_000)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--isa-json", type=Path)
    parser.add_argument("--source-integrity-json", type=Path)
    parser.add_argument("--build-info", type=Path)
    parser.add_argument("--log-file", type=Path)
    parser.add_argument("--result-json", type=Path)
    return parser.parse_args()


def load_json(path):
    if path is None or not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def load_key_values(path):
    result = {}
    if path is None or not path.is_file():
        return result
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result


def emit(lines, text=""):
    print(text, flush=True)
    lines.append(text)


def h3_bitmap_status(bitmap_length, bitmap_words, group_id, bit_position):
    if bitmap_length is None:
        return "unknown"
    index = group_id * 64 + bit_position
    if index >= bitmap_length:
        return "not-enumerated"
    word_index = index >> 5
    if word_index not in bitmap_words:
        return "unknown"
    return "yes" if ((bitmap_words[word_index] >> (index & 31)) & 1) else "no"


def status_to_bool(status):
    if status == "yes":
        return True
    if status == "no":
        return False
    return None


def populate_c_api_statuses(hardware_status, bitmap_length, bitmap_words):
    for name, group_id, bit_position, _description in C_API_EXTENSIONS:
        if name not in hardware_status:
            hardware_status[name] = h3_bitmap_status(
                bitmap_length, bitmap_words, group_id, bit_position
            )


def print_non_hazard3_extensions(output_lines, hardware_status):
    emit(output_lines, "Standard RISC-V C API extensions outside Hazard3 v1.1.1 implementation set:")
    for name, _group_id, _bit_position, description in C_API_EXTENSIONS:
        if name in HAZARD3_C_API_EXTENSIONS:
            continue
        emit(output_lines, f"   {name} = {hardware_status.get(name, 'unknown')};  {description}")


def main():
    args = parse_args()
    if not args.elf.is_file():
        raise SystemExit(f"CoreMark ELF not found: {args.elf}")
    if not args.loader.is_file():
        raise SystemExit(f"Loader not found: {args.loader}")

    isa_report = load_json(args.isa_json)
    source_report = load_json(args.source_integrity_json)
    build_info = load_key_values(args.build_info)

    total_ticks = None
    hazard_cycles = None
    instructions = None
    iterations = None
    misa = None
    hardware_status = {}
    h3_bitmap_length = None
    h3_bitmap_words = {}
    validated = False
    saw_error = False
    saw_done = False
    deadline = time.monotonic() + args.timeout
    output_lines = []
    external_debug_load = False

    with serial.Serial(args.port, args.baud, timeout=0.25) as ser:
        ser.reset_input_buffer()
        subprocess.run([str(args.loader), str(args.elf)], check=True)
        external_debug_load = True

        while time.monotonic() < deadline:
            raw = ser.readline()
            if not raw:
                continue
            line = raw.decode("ascii", errors="replace").rstrip("\r\n")
            emit(output_lines, line)

            match = TICKS_RE.match(line)
            if match:
                total_ticks = int(match.group(1))
            match = ITERATIONS_RE.match(line)
            if match:
                iterations = int(match.group(1))
            match = HAZARD_CYCLES_RE.match(line)
            if match:
                hazard_cycles = int(match.group(1))
            match = HAZARD_INSTRUCTIONS_RE.match(line)
            if match:
                instructions = int(match.group(1))
            match = MISA_RE.match(line)
            if match:
                misa = match.group(1)
            match = ISA_RE.match(line)
            if match:
                hardware_status[match.group(1)] = match.group(2)
            match = H3_BITMAP_LENGTH_RE.match(line)
            if match:
                h3_bitmap_length = int(match.group(1))
            match = H3_BITMAP_WORD_RE.match(line)
            if match:
                h3_bitmap_words[int(match.group(1))] = int(match.group(2), 16)
            if "Correct operation validated." in line:
                validated = True
            if "ERROR!" in line or "Errors detected" in line:
                saw_error = True
            if line == "COREMARK_DONE":
                saw_done = True
                break
        else:
            raise SystemExit(f"Timed out after {args.timeout:g} seconds waiting for CoreMark")

    if not saw_done:
        raise SystemExit("CoreMark output ended without COREMARK_DONE")
    if iterations is None:
        raise SystemExit("CoreMark completed, but Iterations was not captured")

    cycles = hazard_cycles if hazard_cycles is not None else total_ticks
    if cycles is None:
        raise SystemExit("CoreMark completed, but no cycle count was captured")
    if cycles == 0:
        raise SystemExit("CoreMark reported zero timing cycles")

    elapsed = cycles / args.clock_hz
    iterations_per_sec = iterations / elapsed
    coremark_per_mhz = iterations_per_sec / (args.clock_hz / 1_000_000.0)
    cpi = cycles / instructions if instructions else None
    instructions_per_iteration = instructions / iterations if instructions else None

    populate_c_api_statuses(hardware_status, h3_bitmap_length, h3_bitmap_words)
    print_non_hazard3_extensions(output_lines, hardware_status)

    isa_compatibility = None
    missing_extensions = []
    unknown_extensions = []
    if isa_report is not None:
        required = isa_report.get("required_extensions", [])
        for extension in required:
            if extension == "RV32E":
                rv32e = status_to_bool(hardware_status.get("RV32E"))
                rv32i = status_to_bool(hardware_status.get("RV32I"))
                if rv32e is None and rv32i is None:
                    unknown_extensions.append(extension)
                elif rv32e is not True and rv32i is not True:
                    missing_extensions.append(extension)
            else:
                status = hardware_status.get(extension)
                if status not in {"yes", "no"}:
                    unknown_extensions.append(extension)
                elif status != "yes":
                    missing_extensions.append(extension)
        if unknown_extensions:
            isa_compatibility = None
        else:
            isa_compatibility = not missing_extensions

    source_ok = source_report is None or source_report.get("status") == "PASS"
    source_revision_match = True
    if source_report is not None and build_info.get("hazard3_commit"):
        source_revision_match = (
            source_report.get("hazard3_commit") == build_info.get("hazard3_commit")
        )

    elf_analysis_match = True
    isa_attribute_match = True
    if isa_report is not None:
        isa_attribute_match = isa_report.get("attribute_match", True)
    if isa_report is not None and isa_report.get("elf_sha256"):
        current_elf_hash = hashlib.sha256(args.elf.read_bytes()).hexdigest()
        elf_analysis_match = current_elf_hash == isa_report.get("elf_sha256")

    timing_ok = elapsed >= 10.0
    run_ok = (
        validated
        and not saw_error
        and timing_ok
        and source_ok
        and source_revision_match
        and elf_analysis_match
        and isa_attribute_match
        and (isa_report is None or isa_compatibility is True)
    )

    emit(output_lines)
    emit(output_lines, "Hazard3 ULX3S CoreMark summary")
    emit(output_lines, f"  cycles                 : {cycles}")
    if instructions is not None:
        emit(output_lines, f"  instructions           : {instructions}")
        emit(output_lines, f"  cycles/instruction     : {cpi:.6f}")
        emit(output_lines, f"  instructions/iteration : {instructions_per_iteration:.3f}")
    emit(output_lines, f"  elapsed seconds        : {elapsed:.6f}")
    emit(output_lines, f"  CoreMark/s             : {iterations_per_sec:.3f}")
    emit(output_lines, f"  CoreMark/MHz           : {coremark_per_mhz:.4f}")
    emit(output_lines, f"  timing >= 10 seconds   : {'PASS' if timing_ok else 'FAIL'}")
    emit(output_lines, f"  validation             : {'PASS' if validated and not saw_error else 'FAIL'}")
    if misa is not None:
        emit(output_lines, f"  hardware misa          : {misa}")
    emit(output_lines, f"  external debug load    : {'PASS' if external_debug_load else 'FAIL'}")
    if isa_report is not None:
        if isa_compatibility is None:
            emit(output_lines, "  ISA compatibility      : UNKNOWN")
        else:
            emit(output_lines, f"  ISA compatibility      : {'PASS' if isa_compatibility else 'FAIL'}")
    if missing_extensions:
        emit(output_lines, f"  missing ISA extensions : {', '.join(missing_extensions)}")
    if unknown_extensions:
        emit(output_lines, f"  unknown ISA extensions : {', '.join(unknown_extensions)}")
    if source_report is not None:
        emit(output_lines, f"  source integrity       : {source_report.get('status', 'UNKNOWN')}")
        emit(output_lines, f"  source revision match  : {'PASS' if source_revision_match else 'FAIL'}")
        emit(output_lines, f"  Hazard3 commit         : {source_report.get('hazard3_commit', 'unknown')}")
    if isa_report is not None:
        use = isa_report.get("instruction_use", {})
        emit(output_lines, f"  ELF Tag_RISCV_arch     : {isa_report.get('tag_riscv_arch', 'unknown')}")
        if isa_report.get("expected_tag_riscv_arch"):
            emit(output_lines, f"  requested ISA          : {isa_report.get('expected_tag_riscv_arch')}")
            emit(output_lines, f"  ISA attribute match    : {'PASS' if isa_report.get('attribute_match') else 'FAIL'}")
        emit(output_lines, f"  ELF instructions       : {isa_report.get('instruction_count', 0)}")
        emit(
            output_lines,
            "  emitted ISA use        : "
            f"C={use.get('C', 0)} M={use.get('M', 0)} A={use.get('A', 0)} "
            f"Zba={use.get('Zba', 0)} Zbb={use.get('Zbb', 0)} "
            f"Zbc={use.get('Zbc', 0)} Zbkb={use.get('Zbkb', 0)} "
            f"Zbkx={use.get('Zbkx', 0)} Zbs={use.get('Zbs', 0)} "
            f"Zcb={use.get('Zcb', 0)} Zilsd={use.get('Zilsd', 0)} "
            f"Zclsd={use.get('Zclsd', 0)} Zcmp={use.get('Zcmp', 0)} "
            f"Zifencei={use.get('Zifencei', 0)}",
        )
        emit(output_lines, f"  ELF analysis match     : {'PASS' if elf_analysis_match else 'FAIL'}")
        emit(output_lines, f"  ELF SHA256             : {isa_report.get('elf_sha256', 'unknown')}")
    if build_info:
        if build_info.get("profile"):
            emit(output_lines, f"  build profile          : {build_info['profile']}")
        if build_info.get("hazard3_doom_commit"):
            emit(output_lines, f"  Hazard3-Doom commit    : {build_info['hazard3_doom_commit']}")
    emit(output_lines, f"  RESULT                  : {'PASS' if run_ok else 'FAIL'}")

    result = {
        "status": "PASS" if run_ok else "FAIL",
        "cycles": cycles,
        "instructions": instructions,
        "iterations": iterations,
        "elapsed_seconds": elapsed,
        "coremark_per_second": iterations_per_sec,
        "coremark_per_mhz": coremark_per_mhz,
        "cycles_per_instruction": cpi,
        "instructions_per_iteration": instructions_per_iteration,
        "timing_valid": timing_ok,
        "validation": validated and not saw_error,
        "isa_compatibility": isa_compatibility,
        "missing_extensions": missing_extensions,
        "unknown_extensions": unknown_extensions,
        "source_integrity": source_report.get("status") if source_report else None,
        "source_revision_match": source_revision_match,
        "elf_analysis_match": elf_analysis_match,
        "isa_attribute_match": isa_attribute_match,
        "external_debug_load": external_debug_load,
        "h3_misa_bitmap_length": h3_bitmap_length,
        "h3_misa_bitmap_words": h3_bitmap_words,
        "misa": misa,
    }

    if args.result_json:
        args.result_json.parent.mkdir(parents=True, exist_ok=True)
        args.result_json.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if args.log_file:
        args.log_file.parent.mkdir(parents=True, exist_ok=True)
        args.log_file.write_text("\n".join(output_lines) + "\n", encoding="utf-8")

    return 0 if run_ok else 1


if __name__ == "__main__":
    sys.exit(main())
