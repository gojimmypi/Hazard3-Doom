#!/usr/bin/env python3
"""Matrix, live watcher, and summary for frozen ULX5M bootloader sweeps.

Only standard-library modules are required. Offline; no FPGA device access.
"""
import argparse
import csv
import io
import json
import shutil
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import zipfile

COLUMNS = ("seed", "status", "fmax_mhz", "margin_mhz", "exit_code", "elapsed_seconds", "log")
STATES = ("PASS", "FAIL", "TIMEOUT", "ERROR")


def matrix(args):
    first, last, size = args.first, args.last, args.per_job
    if not 1 <= first <= last <= 2147483647 or not 1 <= size <= 5:
        raise ValueError("Expected 1 <= first <= last <= 2147483647 and per-job 1..5")
    items = []
    for start in range(first, last + 1, size):
        end = min(start + size - 1, last)
        items.append({"first": start, "last": end, "group": f"{start}-{end}"})
    if len(items) > 256:
        raise ValueError("GitHub matrix exceeds 256 jobs; increase seeds_per_job or split the sweep")
    print(json.dumps({"include": items}, separators=(",", ":")))


def read_result(stream):
    rows = list(csv.DictReader(io.StringIO(stream.read().decode("utf-8-sig")), delimiter="\t"))
    if not rows:
        raise ValueError("empty results.tsv")
    for row in rows:
        if not all(key in row for key in COLUMNS):
            raise ValueError("invalid results.tsv columns")
        if row["status"] not in STATES:
            raise ValueError(f"invalid status {row['status']!r}")
        row["seed"] = int(row["seed"])
    return rows


def result_from_zip(data):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        matches = [name for name in archive.namelist() if name.endswith("results.tsv")]
        if len(matches) != 1:
            raise ValueError(f"Expected one results.tsv, got {matches}")
        return read_result(archive.open(matches[0]))


class GitHubRedirectHandler(HTTPRedirectHandler):
    """Do not send GitHub's bearer token to artifact storage redirects."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected is not None and urlsplit(req.full_url).netloc != urlsplit(redirected.full_url).netloc:
            redirected.remove_header("Authorization")
        return redirected


def request_api(path, token, raw=False):
    url = f"https://api.github.com/{path.lstrip('/')}"
    req = Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "ulx5m-bootloader-seed-watcher",
    })
    with build_opener(GitHubRedirectHandler()).open(req, timeout=30) as response:
        data = response.read()
    return data if raw else json.loads(data)


def paged(repo, run_id, token, collection):
    entries = []
    for page in range(1, 51):
        url = f"repos/{repo}/actions/runs/{run_id}/{collection}?per_page=100&page={page}"
        response = request_api(url, token)
        batch = response["artifacts" if collection == "artifacts" else "jobs"]
        entries.extend(batch)
        if len(batch) < 100:
            break
    return entries


def print_counts(rows, total):
    counts = {name: 0 for name in STATES}
    for row in rows:
        counts[row["status"]] += 1
    passed = sorted((r for r in rows if r["status"] == "PASS"),
                    key=lambda r: (-float(r["fmax_mhz"]), r["seed"]))
    best = f"best seed {passed[0]['seed']} at {passed[0]['fmax_mhz']} MHz" if passed else "no passing seed yet"
    print(f"LIVE: {len(rows)}/{total} seeds | " + " ".join(f"{key}={value}" for key, value in counts.items())
          + f" | {best}", flush=True)


def watch(args):
    repo = os.environ["GITHUB_REPOSITORY"]
    run_id = os.environ["GITHUB_RUN_ID"]
    token = os.environ["GH_TOKEN"]
    expect_groups = (args.last - args.first + args.per_job) // args.per_job
    prefix = f"ulx5m-bootloader-group-{args.target}-"
    suffix = f"-{run_id}"
    seen = set()
    by_seed = {}
    done_since = None
    last_heartbeat = 0
    print(f"Watching {args.target}: seeds {args.first}-{args.last}, "
          f"{expect_groups} groups, {args.per_job} seeds/group", flush=True)
    while len(seen) < expect_groups:
        try:
            arts = paged(repo, run_id, token, "artifacts")
            for art in arts:
                name = art["name"]
                if not name.startswith(prefix) or not name.endswith(suffix) or name in seen or art.get("expired"):
                    continue
                data = request_api(f"repos/{repo}/actions/artifacts/{art['id']}/zip", token, raw=True)
                rows = result_from_zip(data)
                group_name = name[len(prefix):-len(suffix)]
                start, end = map(int, group_name.split("-"))
                expected = set(range(start, end + 1))
                if {r["seed"] for r in rows} != expected:
                    print(f"WARNING: incomplete artifact {name}", flush=True)
                seen.add(name)
                for row in rows:
                    by_seed[row["seed"]] = row
                print(f"Completed group {group_name}: " + ", ".join(
                    f"{r['seed']}={r['status']}({r['fmax_mhz']}MHz)" for r in rows), flush=True)
                print_counts(list(by_seed.values()), args.last - args.first + 1)
            if len(seen) >= expect_groups:
                break
            # Avoid waiting forever if route jobs failed before uploading artifacts.
            jobs = paged(repo, run_id, token, "jobs")
            routes = [job for job in jobs if job["name"].startswith("Route ")]
            if len(routes) >= expect_groups and all(job["status"] == "completed" for job in routes):
                if done_since is None:
                    done_since = time.monotonic()
                if time.monotonic() - done_since > 90:
                    print(f"WARNING: only {len(seen)}/{expect_groups} group artifacts appeared.", flush=True)
                    return 0
            if time.monotonic() - last_heartbeat >= 180:
                print(f"Watcher heartbeat: {len(seen)}/{expect_groups} groups uploaded", flush=True)
                last_heartbeat = time.monotonic()
        except HTTPError as exc:
            if exc.code in (401, 403, 415):
                print(f"ERROR: non-retryable watcher HTTP {exc.code}: {exc.reason}", flush=True)
                return 1
            print(f"Watcher API retry: {exc}", flush=True)
        except (URLError, ValueError, KeyError, zipfile.BadZipFile) as exc:
            print(f"Watcher API retry: {exc}", flush=True)
        time.sleep(20)
    print("Live watcher complete.", flush=True)
    return 0


def summarize(args):
    by_seed = {}
    duplicate = []
    inconsistent_hashes = []
    manifest = Path(args.frozen) / "SHA256SUMS"
    expected_hashes = [line.split()[0] for line in manifest.read_text(encoding="ascii").splitlines()]
    target_groups = sorted(Path(args.groups).rglob("results.tsv"))
    for path in target_groups:
        source_hash_file = path.parent / "inputs.sha256"
        if not source_hash_file.is_file():
            inconsistent_hashes.append(str(path.parent))
        else:
            found_hashes = [line.split()[0] for line in source_hash_file.read_text(encoding="ascii").splitlines()]
            if found_hashes != expected_hashes:
                inconsistent_hashes.append(str(path.parent))
        with path.open("rb") as file:
            rows = read_result(file)
        for row in rows:
            if row["seed"] in by_seed:
                duplicate.append(row["seed"])
            by_seed[row["seed"]] = row
    requested = set(range(args.first, args.last + 1))
    actual = set(by_seed)
    missing = sorted(requested - actual)
    unexpected = sorted(actual - requested)
    rows = [by_seed[seed] for seed in sorted(actual)]
    counts = {name: sum(r["status"] == name for r in rows) for name in STATES}
    passes = sorted((row for row in rows if row["status"] == "PASS"),
                    key=lambda row: (-float(row["fmax_mhz"]), row["seed"]))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    with (out / "results.tsv").open("w", newline="", encoding="ascii") as file:
        writer = csv.DictWriter(file, COLUMNS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    with (out / "passing-ranked.tsv").open("w", newline="", encoding="ascii") as file:
        writer = csv.DictWriter(file, COLUMNS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in passes:
            writer.writerow(row)
    metadata = Path(args.frozen) / "metadata.txt"
    lines = ["## ULX5M-GS bootloader seed sweep", "",
             f"- Target: `{args.target}`", f"- Seed range: {args.first}-{args.last}",
             "- Required routed clock: 48.00 MHz (`bram_i.clk`)",
             f"- Results: **{counts['PASS']} PASS**, {counts['FAIL']} FAIL, "
             f"{counts['TIMEOUT']} TIMEOUT, {counts['ERROR']} ERROR", "",
             "### Top passing seeds", "", "| Seed | Routed Fmax (MHz) | Margin (MHz) |",
             "| ---: | ---: | ---: |"]
    for row in passes[:30]:
        lines.append(f"| {row['seed']} | {row['fmax_mhz']} | {row['margin_mhz']} |")
    if not passes:
        lines.append("| None | - | - |")
    if passes:
        best_seed = passes[0]["seed"]
        bitstreams = list(Path(args.groups).rglob(f"best-seed-{best_seed}.bit"))
        if len(bitstreams) == 1:
            best_dest = out / f"best-seed-{best_seed}.bit"
            shutil.copyfile(bitstreams[0], best_dest)
            import hashlib
            digest = hashlib.sha256(best_dest.read_bytes()).hexdigest()
            (out / "best-bitstream.sha256").write_text(f"{digest}  {best_dest.name}\n", encoding="ascii")
            lines.extend(["", f"Best candidate bitstream: `{best_dest.name}` (not hardware tested)."])
        else:
            inconsistent_hashes.append(f"Best candidate bitstream missing for seed {best_seed}")
    if metadata.exists():
        lines.extend(["", "### Frozen build information", "", "```text"])
        lines.extend(metadata.read_text(encoding="ascii").strip().splitlines())
        lines.append("```")
    if missing or unexpected or duplicate or inconsistent_hashes:
        lines.extend(["", f"Incomplete/inconsistent results: missing={missing}, unexpected={unexpected}, "
                      f"duplicate={duplicate}, hash_errors={inconsistent_hashes}."])
    lines.extend(["", "Timing passes do not establish USB/DFU function or safe flash operation.", ""])
    (out / "summary.md").write_text("\n".join(lines), encoding="ascii")
    print("\n".join(lines))
    # Incomplete/error sweeps fail; normal timing FAILs/timeouts are valid findings.
    if missing or unexpected or duplicate or inconsistent_hashes or counts["ERROR"] or not passes:
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("matrix")
    p.add_argument("--first", type=int, required=True)
    p.add_argument("--last", type=int, required=True)
    p.add_argument("--per-job", type=int, required=True)
    p = sub.add_parser("watch")
    p.add_argument("--first", type=int, required=True)
    p.add_argument("--last", type=int, required=True)
    p.add_argument("--per-job", type=int, required=True)
    p.add_argument("--target", required=True)
    p = sub.add_parser("summarize")
    p.add_argument("--first", type=int, required=True)
    p.add_argument("--last", type=int, required=True)
    p.add_argument("--target", required=True)
    p.add_argument("--groups", required=True)
    p.add_argument("--frozen", required=True)
    p.add_argument("--out", required=True)
    args = parser.parse_args()
    try:
        result = {"matrix": matrix, "watch": watch, "summarize": summarize}[args.command](args)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    return result or 0


if __name__ == "__main__":
    sys.exit(main())
