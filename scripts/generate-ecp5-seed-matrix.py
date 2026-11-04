#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        generate-ecp5-seed-matrix.py
# Path:        scripts/generate-ecp5-seed-matrix.py
#
# Project:     Hazard3-Doom
# Purpose:     Build the GitHub Actions matrix for grouped ECP5 seed sweeps.
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

import argparse
import json


# nextpnr uses a signed 32-bit seed; GitHub supports at most 256 matrix jobs.
MAX_SEED = 2**31 - 1
MAX_SWEEP_SEEDS = 512
MAX_MATRIX_JOBS = 256


def positive_integer(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("value must be a positive integer")
    return parsed


def seed_integer(value: str) -> int:
    parsed = positive_integer(value)
    if parsed > MAX_SEED:
        raise argparse.ArgumentTypeError(f"seed must be <= {MAX_SEED}")
    return parsed


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate grouped ECP5 seed jobs as a GitHub Actions matrix."
    )
    parser.add_argument("--first", type=seed_integer, required=True)
    parser.add_argument("--last", type=seed_integer, required=True)
    parser.add_argument("--per-job", type=positive_integer, required=True)
    args = parser.parse_args()

    if args.first > args.last:
        parser.error("--first must be less than or equal to --last")

    seed_count = args.last - args.first + 1
    if seed_count > MAX_SWEEP_SEEDS:
        parser.error(f"maximum {MAX_SWEEP_SEEDS} consecutive seeds per sweep")
    if (seed_count + args.per_job - 1) // args.per_job > MAX_MATRIX_JOBS:
        parser.error(
            f"GitHub Actions allows at most {MAX_MATRIX_JOBS} matrix jobs; "
            "increase --per-job for this seed count"
        )

    seeds = range(args.first, args.last + 1)
    groups = []
    current = []
    for seed in seeds:
        current.append(seed)
        if len(current) == args.per_job:
            groups.append(current)
            current = []
    if current:
        groups.append(current)

    matrix = {
        "include": [
            {
                "group": f"{index:02d}",
                "seeds": " ".join(str(seed) for seed in group),
            }
            for index, group in enumerate(groups, start=1)
        ]
    }
    print(json.dumps(matrix, separators=(",", ":")))


if __name__ == "__main__":
    main()
