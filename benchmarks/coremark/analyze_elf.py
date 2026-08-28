#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

INSTRUCTION_RE = re.compile(r"^\s*[0-9a-fA-F]+:\s+[0-9a-fA-F]+\s+([A-Za-z0-9_.]+)\b")
ARCH_RE = re.compile(r"Tag_RISCV_arch:\s*\"?([^\"\r\n]+)\"?")

M_INSTRUCTIONS = {
    "mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu",
}
A_PREFIXES = ("lr.", "sc.", "amo")
ZBA_INSTRUCTIONS = {
    "add.uw", "sh1add", "sh1add.uw", "sh2add", "sh2add.uw",
    "sh3add", "sh3add.uw", "slli.uw",
}
ZBB_INSTRUCTIONS = {
    "andn", "orn", "xnor", "clz", "clzw", "ctz", "ctzw", "cpop",
    "cpopw", "max", "maxu", "min", "minu", "sext.b", "sext.h",
    "zext.h", "rol", "rolw", "ror", "rori", "roriw", "rorw",
    "orc.b", "rev8",
}
ZBC_INSTRUCTIONS = {"clmul", "clmulh", "clmulr"}
ZBKB_ONLY_INSTRUCTIONS = {"brev8", "pack", "packh", "packw", "zip", "unzip"}
ZBKX_INSTRUCTIONS = {"xperm4", "xperm8"}
ZBS_INSTRUCTIONS = {"bclr", "bclri", "bext", "bexti", "binv", "binvi", "bset", "bseti"}
ZCB_INSTRUCTIONS = {
    "c.lbu", "c.lh", "c.lhu", "c.sb", "c.sh", "c.zext.b", "c.sext.b",
    "c.zext.h", "c.sext.h", "c.not", "c.mul",
}
ZILSD_INSTRUCTIONS = {"ld", "sd"}
ZCLSD_INSTRUCTIONS = {"c.ld", "c.ldsp", "c.sd", "c.sdsp"}
ZCMP_INSTRUCTIONS = {"cm.push", "cm.pop", "cm.popret", "cm.popretz", "cm.mva01s", "cm.mvsa01"}

STANDARD_EXTENSIONS = [
    "D", "F", "H", "Q", "V", "B", "M", "A", "C",
    "Zacas", "Zba", "Zbb", "Zbc", "Zbkb", "Zbkc", "Zbkx", "Zbs",
    "Zfa", "Zfh", "Zfhmin", "Zicboz", "Zicond", "Zihintntl",
    "Zihintpause", "Zknd", "Zkne", "Zknh", "Zksed", "Zksh", "Zkt",
    "Ztso", "Zvbb", "Zvbc", "Zvfh", "Zvfhmin", "Zvkb", "Zvkg",
    "Zvkned", "Zvknha", "Zvknhb", "Zvksed", "Zvksh", "Zvkt",
    "Zve32x", "Zve32f", "Zve64x", "Zve64f", "Zve64d", "Zimop",
    "Zca", "Zcb", "Zcd", "Zcf", "Zcmop", "Zawrs", "Zilsd", "Zclsd",
    "Zcmp", "Zifencei", "Zmmul", "Zibi", "Supm", "Zicntr", "Zihpm",
    "Zfbfmin", "Zvfbfmin", "Zvfbfwma", "Zicbom", "Zaamo", "Zalrsc",
    "Zabha", "Zalasr", "Zicbop", "Zicfilp", "Zicfiss", "Zicsr",
]


def run_command(command):
    result = subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "command failed")
    return result.stdout


def parse_args():
    parser = argparse.ArgumentParser(description="Analyze RISC-V ISA usage in a CoreMark ELF")
    parser.add_argument("--elf", required=True, type=Path)
    parser.add_argument("--readelf", required=True)
    parser.add_argument("--objdump", required=True)
    parser.add_argument("--json", required=True, type=Path)
    parser.add_argument("--text", required=True, type=Path)
    parser.add_argument("--expected-arch-object", type=Path)
    return parser.parse_args()


def arch_has(arch: str, extension: str) -> bool:
    lower = arch.lower().strip()
    if extension == "RV32I":
        return lower.startswith("rv32i")
    if extension == "RV32E":
        return lower.startswith("rv32e")
    if extension in {"B", "M", "A", "C", "D", "F", "H", "Q", "V"}:
        letter = extension.lower()
        if re.search(rf"(?:^|_){letter}(?:\d|p|$|_)", lower):
            return True
        first = lower.split("_", 1)[0]
        compact = re.sub(r"\d+p\d+|\d+", "", first[4:])
        return letter in compact
    name = extension.lower()
    return re.search(rf"(?:^|_){re.escape(name)}(?:\d|p|$|_)", lower) is not None


def classify(mnemonic: str, counts: Counter):
    if mnemonic.startswith("c."):
        counts["C"] += 1
    if mnemonic in M_INSTRUCTIONS:
        counts["M"] += 1
    if mnemonic.startswith(A_PREFIXES):
        counts["A"] += 1
    if mnemonic in ZBA_INSTRUCTIONS:
        counts["Zba"] += 1
    if mnemonic in ZBB_INSTRUCTIONS:
        counts["Zbb"] += 1
    if mnemonic in ZBC_INSTRUCTIONS:
        counts["Zbc"] += 1
    if mnemonic in ZBKB_ONLY_INSTRUCTIONS:
        counts["Zbkb"] += 1
    if mnemonic in ZBKX_INSTRUCTIONS:
        counts["Zbkx"] += 1
    if mnemonic in ZBS_INSTRUCTIONS:
        counts["Zbs"] += 1
    if mnemonic in ZCB_INSTRUCTIONS:
        counts["Zcb"] += 1
    if mnemonic in ZILSD_INSTRUCTIONS:
        counts["Zilsd"] += 1
    if mnemonic in ZCLSD_INSTRUCTIONS:
        counts["Zclsd"] += 1
    if mnemonic in ZCMP_INSTRUCTIONS:
        counts["Zcmp"] += 1
    if mnemonic == "fence.i":
        counts["Zifencei"] += 1
    if mnemonic.startswith("csr"):
        counts["Zicsr"] += 1


def main():
    args = parse_args()
    if not args.elf.is_file():
        raise SystemExit(f"ELF not found: {args.elf}")

    try:
        attributes = run_command([args.readelf, "-A", str(args.elf)])
        disassembly = run_command([args.objdump, "-d", "-M", "no-aliases", str(args.elf)])
        expected_attributes = None
        if args.expected_arch_object is not None:
            expected_attributes = run_command([args.readelf, "-A", str(args.expected_arch_object)])
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc

    arch_match = ARCH_RE.search(attributes)
    arch = arch_match.group(1).strip() if arch_match else "unknown"
    expected_arch = None
    if expected_attributes is not None:
        expected_match = ARCH_RE.search(expected_attributes)
        expected_arch = expected_match.group(1).strip() if expected_match else "unknown"
    attribute_match = expected_arch is None or arch == expected_arch

    counts = Counter()
    mnemonic_counts = Counter()
    total = 0
    for line in disassembly.splitlines():
        match = INSTRUCTION_RE.match(line)
        if not match:
            continue
        mnemonic = match.group(1).lower()
        total += 1
        mnemonic_counts[mnemonic] += 1
        classify(mnemonic, counts)

    extensions = ["RV32I", "RV32E", *STANDARD_EXTENSIONS]
    required = [extension for extension in extensions if arch_has(arch, extension)]
    elf_hash = hashlib.sha256(args.elf.read_bytes()).hexdigest()

    report = {
        "elf": str(args.elf),
        "elf_sha256": elf_hash,
        "tag_riscv_arch": arch,
        "expected_tag_riscv_arch": expected_arch,
        "attribute_match": attribute_match,
        "required_extensions": required,
        "instruction_count": total,
        "instruction_use": {name: counts[name] for name in [
            "C", "M", "A", "Zba", "Zbb", "Zbc", "Zbkb", "Zbkx", "Zbs",
            "Zcb", "Zilsd", "Zclsd", "Zcmp", "Zifencei", "Zicsr"
        ]},
        "top_mnemonics": mnemonic_counts.most_common(20),
    }

    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    lines = [
        "CoreMark ELF ISA analysis",
        f"  Tag_RISCV_arch : {arch}",
    ]
    if expected_arch is not None:
        lines.extend([
            f"  expected arch  : {expected_arch}",
            f"  ISA attributes : {'PASS' if attribute_match else 'FAIL'}",
        ])
    lines.extend([
        f"  instructions   : {total}",
        f"  compressed (C) : {counts['C']}",
        f"  M              : {counts['M']}",
        f"  A              : {counts['A']}",
        f"  Zba            : {counts['Zba']}",
        f"  Zbb            : {counts['Zbb']}",
        f"  Zbc            : {counts['Zbc']}",
        f"  Zbkb-only      : {counts['Zbkb']}",
        f"  Zbkx           : {counts['Zbkx']}",
        f"  Zbs            : {counts['Zbs']}",
        f"  Zcb            : {counts['Zcb']}",
        f"  Zilsd          : {counts['Zilsd']}",
        f"  Zclsd          : {counts['Zclsd']}",
        f"  Zcmp           : {counts['Zcmp']}",
        f"  Zifencei       : {counts['Zifencei']}",
        f"  Zicsr          : {counts['Zicsr']}",
        f"  ELF SHA256     : {elf_hash}",
    ])
    text = "\n".join(lines) + "\n"
    args.text.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0 if attribute_match else 1


if __name__ == "__main__":
    sys.exit(main())
