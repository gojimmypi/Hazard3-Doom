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
import os
import statistics
import math
from pathlib import Path


PREFERRED_MARGIN_PERCENT = 10.0


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
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--validate-completed-seed", action="store_true",
                        help="validate exactly one completed result without writing a summary")
    args = parser.parse_args()
    if args.validate_completed_seed:
        if args.seed_first != args.seed_last:
            parser.error("--validate-completed-seed requires exactly one seed")
    elif args.output_dir is None:
        parser.error("--output-dir is required for summary generation")
    return args


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
        number = float(value) if value is not None else None
        return number if number is not None and math.isfinite(number) else None
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


def performance_row(args, metadata, configuration, rows):
    """A stable one-row-per-run schema, including valid timing misses."""
    complete = [row for row in rows if row['route_exit'] == 0
                and row['timing_status'] in ('PASS', 'FAIL')]
    record = {
        'run_id': os.environ.get('GITHUB_RUN_ID', ''),
        'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT', ''),
        'ref': os.environ.get('GITHUB_REF', ''),
        'generated_utc': metadata.get('generated_utc', ''),
        'board': args.target,
        'suite_version': configuration.get('synth_oss_cad_suite_version', ''),
        'route_suite_version': configuration.get('route_oss_cad_suite_version', ''),
        'yosys_version': configuration.get('yosys_version', ''),
        'nextpnr_version': configuration.get('nextpnr_version', ''),
        'packer_name': configuration.get('packer_name', ''),
        'packer_sha256': configuration.get('packer_sha256', ''),
        'git_sha': configuration.get('git_sha', ''),
        'netlist_sha256': metadata.get('netlist_sha256', ''),
        'device': metadata.get('fpga_part', metadata.get('device', '')),
        'speed_grade': metadata.get('speed', ''),
        'package': metadata.get('package', ''),
        'seed_first': args.seed_first,
        'seed_last': args.seed_last,
        'seeds': len(rows),
        'completed': len(complete),
        'pass_count': sum(row['all_timing_pass'] == 'PASS' for row in rows),
        'timing_fail_count': sum(row['all_timing_pass'] != 'PASS' for row in complete),
        'timeout_count': sum(row['route_exit'] in (124, 137) or row['timing_status'] == 'TIMEOUT' for row in rows),
        'missing_count': sum(row['route_exit'] == '' for row in rows),
        'tool_error_count': sum(row['route_exit'] not in (0, 124, 137, '') or
                                (row['route_exit'] == 0 and row['timing_status'] not in ('PASS', 'FAIL'))
                                for row in rows),
        'synthesis_seconds': metadata.get('synthesis_seconds', ''),
    }
    def values(column):
        numbers = [numeric(str(row.get(column, ''))) for row in complete]
        return [number for number in numbers if number is not None and math.isfinite(number)]
    for column in CLOCK_COLUMNS:
        prefix = column.removesuffix('_mhz')
        numbers = values(column)
        record[f'{prefix}_required_mhz'] = metadata.get(f'{prefix}_required_mhz', '')
        for name, function in [('min', min), ('median', statistics.median), ('max', max)]:
            record[f'{prefix}_{name}_mhz'] = f'{function(numbers):.2f}' if numbers else ''
    durations = values('route_seconds')
    record['median_route_seconds'] = statistics.median(durations) if durations else ''
    # Preserve comparable configuration, including any route tuning and cache flags.
    for key in ('hdmi_output_resolution', 'ulx3s_85f_extended_modes', 'ulx3s_12f_memory_profile',
                'ulx4m_sys_clk_mhz', 'ulx4m_litedram_cpu', 'ulx5m_sys_clk_mhz',
                'ulx5m_heap_beta', 'placer', 'router', 'heap_timingweight', 'heap_critexp',
                'tmg_ripup', 'router2_alt_weights', 'nextpnr_extra_args',
                'ulx3s_85f_registered_read_hits', 'ulx3s_85f_sram_write_buffer',
                'ulx3s_85f_sram_dual_port_rw', 'ulx3s_85f_cache_tag_pipeline',
                'ulx3s_85f_tag_ram_mode', 'ulx3s_85f_cache_addr_pipeline'):
        record[key] = configuration.get(key, metadata.get(key, ''))
    return record


def write_performance(path, record):
    with path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(record))
        writer.writeheader()
        writer.writerow(record)


def main() -> int:
    args = parse_args()
    metadata = read_key_values(args.metadata)
    configuration = read_key_values(args.configuration) if args.configuration else {}
    schema = result_schema(metadata)

    board_clocks = {
        'ulx3s-12f': ('clk_sys_mhz', 'clk_video_mhz', 'clk_tmds_mhz'),
        'ulx3s-45f': ('clk_sys_mhz', 'clk_video_mhz', 'clk_tmds_mhz'),
        'ulx3s-85f': ('clk_sys_mhz', 'clk_video_mhz', 'clk_tmds_mhz'),
        'ulx4m-ld-85f': ('clk_sys_mhz', 'litedram_user_mhz', 'clk_video_mhz',
                         'clk_tmds_mhz', 'init_clk_mhz'),
        'ulx5m-gs': ('clk_sys_mhz',),
    }
    if args.target not in board_clocks:
        raise ValueError(f'Unsupported sweep target: {args.target}')
    expected = board_clocks[args.target]
    if schema != ('seed', *expected, 'route_seconds', 'timing_status'):
        raise ValueError(f'Invalid result schema for {args.target}: {schema}')
    if args.seed_first < 1 or args.seed_last < args.seed_first:
        raise ValueError('Invalid seed range')
    requirements: dict[str, float] = {}
    for column in expected:
        key = column.removesuffix('_mhz') + '_required_mhz'
        value = numeric(metadata.get(key))
        if value is None or value <= 0:
            raise ValueError(f'Missing or invalid clock requirement: {key}')
        requirements[column] = value

    rows: list[dict[str, object]] = []
    for seed in range(args.seed_first, args.seed_last + 1):
        result = read_result(args.seed_dir / f"result-seed-{seed}.csv", schema)
        # Never attribute a result from another seed to this seed.
        if result is not None and result.get('seed') != str(seed):
            result = None
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
            clock_values[column] is not None and clock_values[column] > 0
            for column in requirements
        )
        timing_status = result.get("timing_status", "") if result else ""
        if route_exit in (124, 137):
            timing_status = "TIMEOUT"
        elif route_exit not in (None, 0) and timing_status in ("PASS", "FAIL"):
            timing_status = "ERROR"
        if route_exit == 0 and timing_status == "PASS" and clocks_present and any(
            clock_values[column] < requirements[column] for column in requirements
        ):
            # A claimed PASS below any frozen requirement is an inconsistent report.
            timing_status = "ERROR"
        # A successful process exit is insufficient if the per-seed result is
        # absent, malformed, or missing any required clock measurement.
        duration_valid = (result_route_seconds is not None and result_route_seconds >= 0
                          and result_route_seconds.is_integer())
        if route_exit == 0 and (not clocks_present or not duration_valid
                                or timing_status not in ("PASS", "FAIL")):
            timing_status = "ERROR"
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

    if args.validate_completed_seed:
        row = rows[0]
        if row["route_exit"] == 0 and row["timing_status"] in ("PASS", "FAIL"):
            return 0
        print(f"Invalid completed result for seed {row['seed']}: "
              f"status={row['timing_status']}, exit={row['route_exit']}")
        return 1

    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary_csv = args.output_dir / "summary.csv"
    summary_md = args.output_dir / "summary.md"

    fieldnames = list(rows[0].keys())
    with summary_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    write_performance(args.output_dir / "toolchain-performance.csv",
                      performance_row(args, metadata, configuration, rows))

    timed_out = [
        row
        for row in rows
        if row["timing_status"] == "TIMEOUT" or row["route_exit"] in (124, 137)
    ]
    completed = [
        row
        for row in rows
        if row["route_exit"] == 0 and row["timing_status"] in ("PASS", "FAIL")
    ]
    passing = [row for row in rows if row["all_timing_pass"] == "PASS"]
    missing = [row for row in rows if row["route_exit"] == ""]
    tool_failures = [
        row for row in rows if row["route_exit"] not in (0, 124, 137, "")
        or (row["route_exit"] == 0 and row["timing_status"] not in ("PASS", "FAIL"))
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

    # Prefer the quickest reproducible route with headroom on every required clock.
    # If no passing seed meets the preferred margin, use the highest-margin PASS.
    margin_floor = 1.0 + PREFERRED_MARGIN_PERCENT / 100.0
    preferred_by_speed = [
        row for row in passing_by_speed
        if float(row["worst_required_ratio"]) >= margin_floor
    ]
    recommended = (
        preferred_by_speed[0]
        if preferred_by_speed else (passing_by_margin[0] if passing_by_margin else None)
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
        # Paste this text into respective scripts/build-[target]-sweep_summary.md files:
        f"## Generated {args.target} seed sweep summary",
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
        "## Recommended seeds",
        "",
        f"Preferred worst-clock margin: {PREFERRED_MARGIN_PERCENT:g}% (selection policy, not a timing requirement).",
        "",
        "A CI/default seed favors short routing time while meeting the preferred margin.",
        "Only timing-passing seeds are considered. If none meets the margin preference,",
        "the highest-margin passing seed is reported as a fallback.",
        "",
        "| Selection | Seed | Limiting clock | Worst ratio | Margin | Route time |",
        "| :--- | ---: | :--- | ---: | ---: | ---: |",
    ]

    def selection_line(label: str, row: dict[str, object] | None) -> str:
        if row is None:
            return f"| {label} | none | - | - | - | - |"
        ratio = float(row["worst_required_ratio"])
        return (
            f"| {label} | {row['seed']} | {clock_label(str(row['limiting_clock']))} | "
            f"{ratio:.3f}x | {(ratio - 1.0) * 100:.1f}% | "
            f"{format_elapsed(str(row['route_seconds']))} |"
        )

    lines.extend([
        selection_line("Recommended CI/default", recommended),
        selection_line("Highest timing margin", passing_by_margin[0] if passing_by_margin else None),
        selection_line("Fastest timing PASS", passing_by_speed[0] if passing_by_speed else None),
        selection_line(f"Fastest PASS with >= {PREFERRED_MARGIN_PERCENT:g}% margin", preferred_by_speed[0] if preferred_by_speed else None),
    ])
    if recommended is not None and not preferred_by_speed:
        lines.extend(["", "No timing-passing seed met the preferred margin; the recommendation is a fallback."])

    lines.extend([
        "",
        "## Required clocks",
        "",
    ])
    if metadata.get("netlist_sha256"):
        lines.extend(["", f"Frozen netlist SHA-256: `{metadata['netlist_sha256']}`"])

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
            "`toolchain-performance.csv` records distributions and run provenance for comparison.",
            "",
        ]
    )

    summary_md.write_text("\n".join(lines), encoding="utf-8")
    print(summary_md.read_text(encoding="utf-8"))

    return 1 if missing or tool_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
