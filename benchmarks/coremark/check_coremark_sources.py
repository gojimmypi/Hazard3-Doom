#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

WORKLOAD_FILES = (
    "core_list_join.c",
    "core_main.c",
    "core_matrix.c",
    "core_state.c",
    "core_util.c",
    "coremark.h",
)


def run_git(root: Path, *args: str, binary: bool = False):
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=not binary,
    )
    if result.returncode != 0:
        message = result.stderr.decode() if binary else result.stderr
        raise RuntimeError(message.strip() or "git command failed")
    return result.stdout


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Verify CoreMark workload files against the pinned Hazard3 Git commit"
    )
    parser.add_argument("--hazard3-root", required=True, type=Path)
    parser.add_argument("--coremark-dir", required=True, type=Path)
    parser.add_argument("--json", type=Path)
    return parser.parse_args()


def main():
    args = parse_args()
    hazard3_root = args.hazard3_root.resolve()
    coremark_dir = args.coremark_dir.resolve()

    try:
        relative_dir = coremark_dir.relative_to(hazard3_root)
    except ValueError as exc:
        raise SystemExit(
            f"CoreMark source integrity cannot be verified: {coremark_dir} is not inside {hazard3_root}"
        ) from exc

    try:
        commit = run_git(hazard3_root, "rev-parse", "HEAD").strip()
    except RuntimeError as exc:
        raise SystemExit(f"CoreMark source integrity cannot be verified: {exc}") from exc

    results = []
    failures = []
    for name in WORKLOAD_FILES:
        working_path = coremark_dir / name
        if not working_path.is_file():
            failures.append(f"missing {working_path}")
            continue

        git_path = (relative_dir / name).as_posix()
        try:
            committed = run_git(hazard3_root, "show", f"HEAD:{git_path}", binary=True)
        except RuntimeError as exc:
            failures.append(f"{git_path}: {exc}")
            continue

        working = working_path.read_bytes()
        working_hash = sha256(working)
        committed_hash = sha256(committed)
        matched = working_hash == committed_hash
        results.append(
            {
                "file": name,
                "git_path": git_path,
                "sha256": working_hash,
                "matches_hazard3_head": matched,
            }
        )
        if not matched:
            failures.append(f"modified workload file: {git_path}")

    report = {
        "status": "PASS" if not failures else "FAIL",
        "hazard3_commit": commit,
        "coremark_dir": str(coremark_dir),
        "files": results,
        "failures": failures,
    }

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(f"CoreMark source integrity : {report['status']}")
    print(f"Hazard3 source commit     : {commit}")
    if failures:
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
