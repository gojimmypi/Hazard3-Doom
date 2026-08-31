#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        summarize-ecp5-sweep.py
# Path:        scripts/summarize-ecp5-sweep.py
#
# Project:     Hazard3-Doom
# Purpose:     Summarize per-seed routed timing results from ECP5 sweep jobs.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

from __future__ import annotations

import argparse
import csv
from pathlib import Path


CLOCK_COLUMNS = {
    "clk_sys_mhz": "clk_sys",
    "litedram_user_mhz": "LiteDRAM user",
    "clk_video_mhz": "video pixel",
    "clk_tmds_mhz": "TMDS x5",
    "init_clk_mhz": "init_clk",
}


def clock_label(column: str) -> str:
    if column in CLOCK_COLUMNS:
        return CLOCK_COLUMNS[column]
    return column.removesuffix("_mhz").replace("_", " ")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--seed-first", type=int, required=True)
    parser.add_argument("--seed-last", type=int, required=True)
    parser.add_argument("--seed-dir", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--configuration", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def read_key_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" not in raw_line:
            continue
        key, value = raw_line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def numeric(value: str | None) -> float | None:
    try:
        return float(value) if value is not None else None
    except ValueError:
        return None


def read_int(path: Path) -> int | None:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (FileNotFoundError, ValueError):
        return None


def result_schema(metadata: dict[str, str]) -> tuple[str, ...]:
    columns = metadata.get("result_columns", "")
    schema = tuple(column.strip() for column in columns.split(",") if column.strip())
    if not schema or schema[0] != "seed" or schema[-1] != "timing_status":
        raise ValueError("Frozen sweep metadata is missing a valid result_columns entry")
    return schema


def read_result(path: Path, schema: tuple[str, ...]) -> dict[str, str] | None:
    if not path.exists():
        return None
    fields = path.read_text(encoding="utf-8", errors="replace").strip().split(",")
    if len(fields) != len(schema):
        return None
    return dict(zip(schema, fields, strict=True))


def format_elapsed(value: str) -> str:
    if not value:
        return ""
    try:
        seconds = int(value)
    except ValueError:
        return value
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes}:{seconds:02d}"


def main() -> int:
    args = parse_args()
    metadata = read_key_values(args.metadata)
    configuration = read_key_values(args.configuration) if args.configuration else {}
    schema = result_schema(metadata)

    requirements: dict[str, float] = {}
    for metadata_key, raw_value in metadata.items():
        if not metadata_key.endswith("_required_mhz"):
            continue
        column = metadata_key.removesuffix("_required_mhz") + "_mhz"
        if column not in schema:
            continue
        value = numeric(raw_value)
        if value is not None:
            requirements[column] = value

    rows: list[dict[str, object]] = []
    for seed in range(args.seed_first, args.seed_last + 1):
        result = read_result(args.seed_dir / f"result-seed-{seed}.csv", schema)
        route_exit = read_int(args.seed_dir / f"exit-{seed}.txt")
        job_elapsed = read_int(args.seed_dir / f"elapsed-{seed}.txt")
        result_route_seconds = numeric(result.get("route_seconds")) if result else None
        route_seconds = (
            int(result_route_seconds) if result_route_seconds is not None else job_elapsed
        )

        clock_values: dict[str, float | None] = {}
        for column in requirements:
            clock_values[column] = numeric(result.get(column)) if result else None

        clocks_present = bool(requirements) and all(
            clock_values[column] is not None for column in requirements
        )
        timing_status = result.get("timing_status", "") if result else ""
        all_timing_pass = (
            route_exit == 0
            and clocks_present
            and timing_status == "PASS"
            and all(
                clock_values[column] is not None
                and clock_values[column] >= requirements[column]
                for column in requirements
            )
        )

        limiting_clock = ""
        worst_ratio: float | None = None
        if clocks_present:
            ratios = {
                column: clock_values[column] / requirements[column]
                for column in requirements
                if clock_values[column] is not None
            }
            limiting_clock = min(ratios, key=ratios.get)
            worst_ratio = ratios[limiting_clock]

        row: dict[str, object] = {
            "seed": seed,
            "route_exit": "" if route_exit is None else route_exit,
            "route_seconds": "" if route_seconds is None else route_seconds,
            "job_elapsed_seconds": "" if job_elapsed is None else job_elapsed,
        }
        for column in schema:
            if not column.endswith("_mhz"):
                continue
            value = clock_values.get(column)
            row[column] = "" if value is None else f"{value:.2f}"
        row.update(
            {
                "timing_status": timing_status,
                "all_timing_pass": "PASS" if all_timing_pass else "FAIL",
                "limiting_clock": limiting_clock,
                "worst_required_ratio": "" if worst_ratio is None else f"{worst_ratio:.6f}",
            }
        )
        rows.append(row)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary_csv = args.output_dir / "summary.csv"
    summary_md = args.output_dir / "summary.md"

    fieldnames = list(rows[0].keys())
    with summary_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    timed_out = [
        row
        for row in rows
        if row["timing_status"] == "TIMEOUT" or row["route_exit"] in (124, 137)
    ]
    completed = [
        row
        for row in rows
        if row["route_exit"] == 0 and row["timing_status"] != "TIMEOUT"
    ]
    passing = [row for row in rows if row["all_timing_pass"] == "PASS"]
    missing = [row for row in rows if row["route_exit"] == ""]
    tool_failures = [
        row for row in rows if row["route_exit"] not in (0, 124, 137, "")
    ]
    timing_failures = [row for row in completed if row["all_timing_pass"] != "PASS"]
    closest = sorted(
        [row for row in completed if row["worst_required_ratio"] != ""],
        key=lambda row: float(row["worst_required_ratio"]),
        reverse=True,
    )
    passing_by_margin = sorted(
        passing,
        key=lambda row: float(row["worst_required_ratio"]),
        reverse=True,
    )
    passing_by_speed = sorted(
        [row for row in passing if row["route_seconds"] != ""],
        key=lambda row: int(row["route_seconds"]),
    )

    pass_seeds = ", ".join(str(row["seed"]) for row in passing)
    clock_pass_counts = {
        column: sum(
            1
            for row in completed
            if row[column] != "" and float(row[column]) >= requirement
        )
        for column, requirement in requirements.items()
    }

    active_clock_columns = [column for column in schema if column in requirements]

    def append_table(lines: list[str], table_rows: list[dict[str, object]]) -> None:
        headers = ["Seed", "Result"]
        headers.extend(clock_label(column) for column in active_clock_columns)
        headers.extend(["Limiting", "Worst ratio", "Route time"])
        lines.append("| " + " | ".join(headers) + " |")
        lines.append("| " + " | ".join(["---:", ":---:"] + ["---:"] * len(active_clock_columns) + [":---", "---:", "---:"]) + " |")
        for row in table_rows:
            values = [str(row["seed"]), str(row["all_timing_pass"])]
            values.extend(str(row[column]) for column in active_clock_columns)
            ratio = row["worst_required_ratio"]
            values.extend(
                [
                    str(row["limiting_clock"]),
                    "" if ratio == "" else f"{float(ratio):.3f}x",
                    format_elapsed(str(row["route_seconds"])),
                ]
            )
            lines.append("| " + " | ".join(values) + " |")

    synthesis_seconds = metadata.get("synthesis_seconds", "")
    synthesis_display = format_elapsed(synthesis_seconds) if synthesis_seconds else "unknown"

    lines = [
        f"# {args.target} seed sweep summary",
        "",
        f"- Synthesis duration: {synthesis_display}" + (f" ({synthesis_seconds} seconds)" if synthesis_seconds.isdigit() else ""),
        f"- Seeds expected: {len(rows)}",
        f"- Routes completed: {len(completed)}",
        f"- Timed-out seeds: {len(timed_out)}",
        f"- TIMEOUT seed values: {', '.join(str(row['seed']) for row in timed_out) or 'none'}",
        f"- Timing-passing seeds: {len(passing)}",
        f"- PASS seed values: {pass_seeds or 'none'}",
        f"- Best combined-margin PASS seed: {passing_by_margin[0]['seed'] if passing_by_margin else 'none'}",
        f"- Fastest timing-passing seed: {passing_by_speed[0]['seed'] if passing_by_speed else 'none'}",
        f"- Completed routes with timing failure: {len(timing_failures)}",
        f"- Route/tool failures: {len(tool_failures)}",
        f"- Missing seed results: {len(missing)}",
        "",
        "## Required clocks",
        "",
    ]
    for column, requirement in requirements.items():
        lines.append(f"- {clock_label(column)}: {requirement:.2f} MHz")

    lines.extend(["", "## Per-clock closure", ""])
    for column in active_clock_columns:
        lines.append(
            f"- {clock_label(column)}: {clock_pass_counts[column]}/{len(completed)}"
        )

    if configuration:
        lines.extend(["", "## Workflow configuration", ""])
        for key in sorted(configuration):
            lines.append(f"- {key}: {configuration[key] or '(none)'}")

    lines.extend(["", "## Closest to full timing closure", ""])
    append_table(lines, closest[:20])

    lines.extend(["", "## Timing-passing seeds by combined margin", ""])
    append_table(lines, passing_by_margin[:20])

    lines.extend(["", "## Fastest timing-passing seeds", ""])
    append_table(lines, passing_by_speed[:20])

    lines.extend(
        [
            "",
            "The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is",
            "recomputed from the required clocks in the frozen sweep metadata.",
            "",
        ]
    )

    summary_md.write_text("\n".join(lines), encoding="utf-8")
    print(summary_md.read_text(encoding="utf-8"))

    return 1 if missing or tool_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
