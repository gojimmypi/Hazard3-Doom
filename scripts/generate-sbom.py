#!/usr/bin/env python3
"""
Generate the Hazard3-Doom CycloneDX SBOM.

The script intentionally uses only the Python standard library.

It records:
- the Hazard3-Doom Git revision in release mode,
- exact pinned Git submodule revisions,
- known third-party/bundled components,
- SHA-256 hashes for files redistributed under bin/,
- dependency relationships between logical packages and bundled files.

By default, output is written to <repo>/bom.json.

Reproducibility and modes:
- Default mode produces a deterministic, check-in-safe bom.json. It deliberately
  omits the root Git revision and generation timestamp so the file does not
  contain a self-reference to the commit that contains it.
- --release produces a deterministic release SBOM for the exact clean HEAD. Its
  timestamp comes from SOURCE_DATE_EPOCH when set, otherwise from the HEAD
  commit timestamp.
- serialNumber is omitted because CycloneDX recommends a unique serial for each
  generated BOM; a deterministic serial would conflict with that guidance.

Usage:
    python3 scripts/generate-sbom.py
    python3 scripts/generate-sbom.py --output build/bom.json
    python3 scripts/generate-sbom.py --check
    python3 scripts/generate-sbom.py --release
"""

from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable


PROJECT_NAME = "Hazard3-Doom"
PROJECT_GROUP = "ulx3s"
PROJECT_URL = "https://github.com/ulx3s/Hazard3-Doom"
DOCS_URL = "https://hazard3-doom.readthedocs.io/"
CYCLONEDX_SCHEMA = "https://cyclonedx.org/schema/bom-1.7.schema.json"
CYCLONEDX_SPEC_VERSION = "1.7"

REQUIRED_SUBMODULES = (
    {
        "path": "third_party/Hazard3",
        "bom_ref": "hazard3",
        "name": "Hazard3",
        "type": "library",
        "license": "Apache-2.0",
        "description": "Hazard3 RISC-V CPU RTL, pinned as a Git submodule.",
        "upstream": "https://github.com/Wren6991/Hazard3",
    },
    {
        "path": "third_party/doomgeneric",
        "bom_ref": "doomgeneric",
        "name": "doomgeneric",
        "type": "library",
        "license": "GPL-2.0-only",
        "description": "Hazard3-Doom's pinned DoomGeneric/DOOM source submodule.",
        "upstream": "https://github.com/ozkl/doomgeneric",
    },
)

BUNDLED_COMPONENTS = (
    {
        "bom_ref": "fujprog",
        "name": "fujprog",
        "type": "application",
        "version": "v4.8",
        "license": "BSD-2-Clause",
        "description": "Bundled Windows FPGA programming utility.",
        "match": ("*fujprog*",),
    },
    {
        "bom_ref": "dfu-util",
        "name": "dfu-util",
        "type": "application",
        "license": "GPL-2.0-or-later",
        "description": "Bundled Windows dfu-util family utilities.",
        "match": ("*dfu-util*", "*dfu-prefix*", "*dfu-suffix*"),
    },
    {
        "bom_ref": "openfpgaloader",
        "name": "openFPGALoader",
        "type": "application",
        "license": "Apache-2.0",
        "description": "Bundled FPGA programming utility.",
        "match": ("*openfpgaloader*",),
    },
    {
        "bom_ref": "openocd-xpack",
        "name": "OpenOCD (xPack distribution)",
        "type": "application",
        "license": "GPL-2.0-or-later",
        "description": "Bundled OpenOCD executable from an xPack distribution.",
        "match": ("*openocd*",),
    },
    {
        "bom_ref": "putty",
        "name": "PuTTY",
        "type": "application",
        "license": "MIT",
        "description": "Bundled Windows terminal/serial utility.",
        "match": (
            "*putty*",
            "*plink*",
            "*pscp*",
            "*psftp*",
            "*pageant*",
            "*puttygen*",
        ),
    },
    {
        "bom_ref": "zadig",
        "name": "Zadig",
        "type": "application",
        "version": "2.5",
        "license": "GPL-3.0-or-later",
        "description": "Bundled Zadig Windows USB driver installation utility.",
        "match": ("*zadig*",),
    },
    {
        "bom_ref": "libftdi1",
        "name": "libftdi1",
        "type": "library",
        "license": "LGPL-2.1-only",
        "description": "Bundled libftdi1 library.",
        "match": ("*libftdi1*", "*libftdi-1*"),
    },
    {
        "bom_ref": "libusb-1.0",
        "name": "libusb-1.0",
        "type": "library",
        "license": "LGPL-2.1-or-later",
        "description": "Bundled libusb-1.0 library.",
        "match": ("*libusb-1.0*",),
    },
    {
        "bom_ref": "riscv-gdb-bundle",
        "name": "RISC-V GNU GDB bundle",
        "type": "application",
        "description": "Redistributed GDB/tooling directory.",
        "path_prefix": "bin/gdb/",
    },
    {
        "bom_ref": "riscv-gcc-bundle",
        "name": "RISC-V GNU GCC toolchain bundle",
        "type": "application",
        "description": "Redistributed RISC-V GNU toolchain directory.",
        "path_prefix": "bin/riscv-gcc/",
    },
)


def run_git(repo: Path, args: Iterable[str], check: bool = True) -> str:
    command = ["git", "-C", str(repo), *args]
    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    if check and result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"{' '.join(command)} failed: {message}")
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def find_repo_root(start: Path) -> Path:
    root = run_git(start, ["rev-parse", "--show-toplevel"], check=False)
    if root:
        return Path(root).resolve()

    current = start.resolve()
    for candidate in (current, *current.parents):
        if (candidate / ".git").exists() or (candidate / ".gitmodules").exists():
            return candidate

    raise RuntimeError("Could not locate the Hazard3-Doom repository root.")


def git_head(repo: Path) -> str:
    head = run_git(repo, ["rev-parse", "HEAD"], check=False)
    return head or "unknown"


def git_head_timestamp(repo: Path) -> int | None:
    value = run_git(repo, ["show", "-s", "--format=%ct", "HEAD"], check=False)
    if value.isdigit():
        return int(value)
    return None


def git_exact_tag(repo: Path) -> str | None:
    value = run_git(
        repo,
        ["describe", "--tags", "--exact-match", "HEAD"],
        check=False,
    )
    return value or None


def path_is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def git_dirty(repo: Path, excluded_paths: Iterable[Path] = ()) -> bool:
    args = ["status", "--porcelain", "--untracked-files=normal", "--", "."]
    repo_resolved = repo.resolve()

    for path in excluded_paths:
        resolved = path.resolve(strict=False)
        if not path_is_within(resolved, repo_resolved):
            continue
        rel = resolved.relative_to(repo_resolved).as_posix()
        args.append(f":(top,literal,exclude){rel}")

    value = run_git(repo, args, check=True)
    return bool(value)


def git_path_tracked(repo: Path, path: Path) -> bool:
    repo_resolved = repo.resolve()
    resolved = path.resolve(strict=False)
    if not path_is_within(resolved, repo_resolved):
        return False

    rel = resolved.relative_to(repo_resolved).as_posix()
    value = run_git(
        repo,
        ["ls-files", "--error-unmatch", "--", rel],
        check=False,
    )
    return bool(value)


def gitlink_sha(repo: Path, path: str) -> str | None:
    output = run_git(repo, ["ls-tree", "HEAD", "--", path], check=False)
    if not output:
        return None

    match = re.match(r"^160000 commit ([0-9a-fA-F]{40})\t", output)
    if not match:
        return None
    return match.group(1).lower()


def index_gitlink_sha(repo: Path, path: str) -> str | None:
    output = run_git(repo, ["ls-files", "--stage", "--", path], check=False)
    if not output:
        return None

    match = re.match(r"^160000 ([0-9a-fA-F]{40}) 0\t", output)
    if not match:
        return None
    return match.group(1).lower()


def checkout_submodule_sha(repo: Path, path: str) -> str | None:
    submodule = repo / path
    if not submodule.is_dir():
        return None

    value = run_git(submodule, ["rev-parse", "HEAD"], check=False)
    if re.fullmatch(r"[0-9a-fA-F]{40}", value):
        return value.lower()
    return None


def submodule_revision(repo: Path, path: str, release: bool) -> str | None:
    if release:
        return gitlink_sha(repo, path)

    return (
        checkout_submodule_sha(repo, path)
        or index_gitlink_sha(repo, path)
        or gitlink_sha(repo, path)
    )


def submodule_url(repo: Path, path: str) -> str | None:
    config_path = repo / ".gitmodules"
    if not config_path.exists():
        return None

    name = run_git(
        repo,
        [
            "config",
            "-f",
            str(config_path),
            "--get-regexp",
            r"^submodule\..*\.path$",
        ],
        check=False,
    )

    for line in name.splitlines():
        try:
            key, value = line.split(maxsplit=1)
        except ValueError:
            continue
        if value != path:
            continue

        prefix = key[: -len(".path")]
        url = run_git(
            repo,
            ["config", "-f", str(config_path), "--get", f"{prefix}.url"],
            check=False,
        )
        return normalize_git_url(url) if url else None

    return None


def normalize_git_url(url: str) -> str:
    value = url.strip()

    if value.startswith("git@github.com:"):
        value = "https://github.com/" + value[len("git@github.com:") :]
    elif value.startswith("ssh://git@github.com/"):
        value = "https://github.com/" + value[len("ssh://git@github.com/") :]

    if value.endswith(".git"):
        value = value[:-4]

    return value


def iso_timestamp(epoch: int) -> str:
    return (
        dt.datetime.fromtimestamp(epoch, tz=dt.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def sbom_epoch(repo: Path) -> int:
    source_date_epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if source_date_epoch is not None:
        try:
            return int(source_date_epoch)
        except ValueError as exc:
            raise RuntimeError("SOURCE_DATE_EPOCH must be an integer.") from exc

    commit_epoch = git_head_timestamp(repo)
    if commit_epoch is not None:
        return commit_epoch

    return int(dt.datetime.now(tz=dt.timezone.utc).timestamp())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_bundled_file(path: Path, bin_dir: Path) -> Path:
    if path.is_symlink():
        raise RuntimeError(f"Refusing to hash symlink under bin/: {path}")

    resolved = path.resolve(strict=True)
    root = bin_dir.resolve(strict=True)
    if not path_is_within(resolved, root):
        raise RuntimeError(f"Bundled file resolves outside bin/: {path}")
    if not resolved.is_file():
        raise RuntimeError(f"Bundled path is not a regular file: {path}")

    return resolved


def declared_license(spdx_id: str) -> list[dict[str, Any]]:
    return [
        {
            "license": {
                "id": spdx_id,
                "acknowledgement": "declared",
            }
        }
    ]


def prop(name: str, value: str) -> dict[str, str]:
    return {"name": name, "value": value}


def vcs(url: str, comment: str | None = None) -> dict[str, str]:
    result = {"type": "vcs", "url": url}
    if comment:
        result["comment"] = comment
    return result


def evidence(url: str, comment: str | None = None) -> dict[str, str]:
    result = {"type": "evidence", "url": url}
    if comment:
        result["comment"] = comment
    return result


def path_matches_component(rel_path: str, component: dict[str, Any]) -> bool:
    path_lower = rel_path.lower()
    prefix = component.get("path_prefix")
    if prefix and path_lower.startswith(prefix.lower()):
        return True

    name_lower = Path(path_lower).name
    for pattern in component.get("match", ()):
        if fnmatch.fnmatch(name_lower, pattern.lower()):
            return True

    return False


def make_file_component(repo: Path, path: Path) -> dict[str, Any]:
    rel = path.relative_to(repo).as_posix()
    return {
        "type": "file",
        "bom-ref": f"file:{rel}",
        "name": path.name,
        "scope": "optional",
        "hashes": [
            {
                "alg": "SHA-256",
                "content": sha256_file(path),
            }
        ],
        "properties": [
            prop("hazard3-doom:bundle-location", rel),
        ],
    }


def collect_bundled_files(
    repo: Path,
) -> tuple[list[dict[str, Any]], dict[str, list[str]], list[str]]:
    bin_dir = repo / "bin"
    if not bin_dir.is_dir():
        return [], {}, []

    file_components: list[dict[str, Any]] = []
    assignments: dict[str, list[str]] = {
        component["bom_ref"]: [] for component in BUNDLED_COMPONENTS
    }
    unmapped: list[str] = []

    for path in sorted(bin_dir.rglob("*")):
        if path.is_symlink():
            raise RuntimeError(f"Refusing symlink under bin/: {path}")
        if not path.is_file():
            continue

        validate_bundled_file(path, bin_dir)
        file_component = make_file_component(repo, path)
        file_components.append(file_component)

        rel = path.relative_to(repo).as_posix()
        assigned = False

        for component in BUNDLED_COMPONENTS:
            if path_matches_component(rel, component):
                assignments[component["bom_ref"]].append(file_component["bom-ref"])
                assigned = True

        if not assigned:
            unmapped.append(file_component["bom-ref"])

    return file_components, assignments, unmapped


def make_submodule_component(
    repo: Path,
    item: dict[str, str],
    release: bool,
    allow_incomplete: bool,
) -> dict[str, Any]:
    revision = submodule_revision(repo, item["path"], release)
    if not revision and not allow_incomplete:
        raise RuntimeError(
            f"Required submodule revision could not be determined: {item['path']}"
        )

    repository = submodule_url(repo, item["path"])
    if not repository:
        repository = item["upstream"]

    component: dict[str, Any] = {
        "type": item["type"],
        "bom-ref": item["bom_ref"],
        "name": item["name"],
        "scope": "required",
        "description": item["description"],
        "licenses": declared_license(item["license"]),
        "externalReferences": [
            vcs(repository),
            vcs(item["upstream"], "Upstream project."),
        ],
        "properties": [
            prop("hazard3-doom:source-path", item["path"]),
        ],
    }

    if revision:
        component["version"] = revision
        component["externalReferences"][0] = vcs(f"{repository}/tree/{revision}")
        component["properties"].append(
            prop(
                "hazard3-doom:provenance-status",
                "Exact pinned Git revision recorded.",
            )
        )
    else:
        component["properties"].append(
            prop(
                "hazard3-doom:provenance-status",
                "Pinned Git revision could not be determined.",
            )
        )

    return component


def make_bundled_component(
    item: dict[str, Any],
    assigned_files: list[str],
) -> dict[str, Any]:
    component: dict[str, Any] = {
        "type": item["type"],
        "bom-ref": item["bom_ref"],
        "name": item["name"],
        "scope": "optional",
        "description": item["description"],
        "properties": [
            prop("hazard3-doom:bundle-location", "bin/"),
        ],
    }

    if "version" in item:
        component["version"] = item["version"]

    if "license" in item:
        component["licenses"] = declared_license(item["license"])

    component["properties"].append(
        prop(
            "hazard3-doom:provenance-status",
            (
                f"{len(assigned_files)} redistributed file(s) matched and "
                "are recorded separately with SHA-256 hashes."
            ),
        )
    )

    return component


def build_bom(
    repo: Path,
    release: bool,
    allow_incomplete: bool,
) -> dict[str, Any]:
    source_revision = git_head(repo) if release else None
    epoch = sbom_epoch(repo) if release else None
    tag = git_exact_tag(repo) if release else None

    if release and source_revision == "unknown" and not allow_incomplete:
        raise RuntimeError("Release SBOM requires a valid Git HEAD revision.")

    root_component: dict[str, Any] = {
        "type": "application",
        "bom-ref": "hazard3-doom",
        "group": PROJECT_GROUP,
        "name": PROJECT_NAME,
        "description": (
            "Doom running on the Hazard3 RISC-V CPU in an ECP5 FPGA, "
            "including monitor firmware, a DoomGeneric application, FPGA "
            "board integrations, host-side upload/flashing tools, and "
            "supporting project assets."
        ),
        "externalReferences": [
            vcs(PROJECT_URL),
            {
                "type": "documentation",
                "url": DOCS_URL,
            },
            {
                "type": "license",
                "url": f"{PROJECT_URL}/blob/main/LICENSING.md",
            },
            evidence(
                f"{PROJECT_URL}/blob/main/LICENSES/BUNDLED-BINARIES-MANIFEST.md",
                (
                    "Repository release-audit manifest for redistributed "
                    "binaries and DLLs."
                ),
            ),
        ],
        "properties": [
            prop(
                "hazard3-doom:sbom-mode",
                "release" if release else "checked-in",
            ),
            prop(
                "hazard3-doom:licensing-model",
                (
                    "Multi-license, per-file/per-component; see LICENSING.md "
                    "and LICENSES/ notices."
                ),
            ),
            prop(
                "hazard3-doom:sbom-scope",
                (
                    "Source tree, pinned source submodules, known bundled "
                    "third-party components, and redistributed convenience "
                    "binaries."
                ),
            ),
            prop(
                "hazard3-doom:excluded-content",
                (
                    "DOOM IWAD/game data is not distributed by Hazard3-Doom "
                    "and is not part of this SBOM."
                ),
            ),
            prop(
                "hazard3-doom:build-environment",
                (
                    "External build toolchains are not modeled unless they "
                    "are redistributed in the repository."
                ),
            ),
        ],
    }

    if source_revision:
        root_component["properties"].append(
            prop("hazard3-doom:source-revision", source_revision)
        )

    if tag:
        root_component["version"] = tag

    components: list[dict[str, Any]] = [
        make_submodule_component(repo, item, release, allow_incomplete)
        for item in REQUIRED_SUBMODULES
    ]

    components.extend(
        [
            {
                "type": "library",
                "bom-ref": "coremark",
                "name": "CoreMark",
                "scope": "excluded",
                "description": (
                    "EEMBC CoreMark benchmark material used for benchmarking "
                    "and verification rather than the Doom runtime."
                ),
                "licenses": declared_license("Apache-2.0"),
                "externalReferences": [
                    vcs("https://github.com/eembc/coremark"),
                ],
                "properties": [
                    prop(
                        "hazard3-doom:provenance-status",
                        (
                            "Exact upstream revision is not established by the "
                            "current root notice; preserve nested provenance "
                            "when redistributed."
                        ),
                    )
                ],
            },
            {
                "type": "firmware",
                "bom-ref": "had2019-bootloader",
                "name": "HAD2019 ULX3S/ULX4M DFU bootloader lineage",
                "scope": "optional",
                "description": (
                    "Bootloader source derived from the "
                    "emard/had2019-playground ULX3S/ULX4M bootloader family. "
                    "Licensing is determined per upstream file."
                ),
                "externalReferences": [
                    vcs(
                        "https://github.com/emard/had2019-playground/"
                        "tree/master/projects/bootloader"
                    ),
                    evidence(
                        f"{PROJECT_URL}/blob/main/"
                        "LICENSES/HAD2019-Bootloader-NOTICE.md"
                    ),
                ],
                "properties": [
                    prop(
                        "hazard3-doom:license-status",
                        (
                            "Mixed per-file licensing includes "
                            "LGPL-3.0-or-later firmware, BSD-3-Clause RTL, ISC "
                            "PicoRV32, and BSD-style mini-printf."
                        ),
                    ),
                    prop(
                        "hazard3-doom:provenance-status",
                        (
                            "Exact upstream revision should be pinned before "
                            "treating a release SBOM as complete."
                        ),
                    ),
                ],
            },
            {
                "type": "library",
                "bom-ref": "picorv32",
                "name": "PicoRV32",
                "scope": "optional",
                "description": (
                    "PicoRV32 CPU core used in the upstream bootloader lineage."
                ),
                "licenses": declared_license("ISC"),
                "externalReferences": [
                    vcs("https://github.com/YosysHQ/picorv32"),
                ],
                "properties": [
                    prop(
                        "hazard3-doom:provenance-status",
                        (
                            "Version inherited from the exact bootloader source; "
                            "not independently pinned here."
                        ),
                    )
                ],
            },
            {
                "type": "library",
                "bom-ref": "mini-printf",
                "name": "mini-printf",
                "scope": "optional",
                "description": (
                    "mini-printf implementation used in the upstream "
                    "bootloader lineage."
                ),
                "licenses": declared_license("BSD-3-Clause"),
                "properties": [
                    prop(
                        "hazard3-doom:provenance-status",
                        (
                            "Version inherited from the exact bootloader source; "
                            "not independently pinned here."
                        ),
                    )
                ],
            },
            {
                "type": "library",
                "bom-ref": "libwdi",
                "name": "libwdi",
                "scope": "optional",
                "description": (
                    "libwdi component associated with the bundled Zadig "
                    "distribution."
                ),
                "licenses": declared_license("LGPL-3.0-or-later"),
                "properties": [
                    prop(
                        "hazard3-doom:provenance-status",
                        (
                            "Exact libwdi revision/version associated with the "
                            "bundled Zadig artifact remains to be pinned."
                        ),
                    )
                ],
            },
        ]
    )

    file_components, assignments, unmapped_files = collect_bundled_files(repo)

    if not assignments["zadig"]:
        components = [
            component
            for component in components
            if component["bom-ref"] != "libwdi"
        ]

    present_bundled_refs: list[str] = []
    for item in BUNDLED_COMPONENTS:
        assigned_files = assignments[item["bom_ref"]]
        if not assigned_files:
            continue
        components.append(make_bundled_component(item, assigned_files))
        present_bundled_refs.append(item["bom_ref"])

    components.extend(file_components)
    components.sort(key=lambda component: component["bom-ref"])

    root_dependencies = [
        item["bom_ref"] for item in REQUIRED_SUBMODULES
    ]
    root_dependencies.extend(
        [
            "had2019-bootloader",
            *present_bundled_refs,
            *unmapped_files,
        ]
    )

    dependencies: list[dict[str, Any]] = [
        {
            "ref": "hazard3-doom",
            "dependsOn": sorted(set(root_dependencies)),
        },
        {
            "ref": "had2019-bootloader",
            "dependsOn": [
                "mini-printf",
                "picorv32",
            ],
        },
    ]

    if "zadig" in present_bundled_refs:
        dependencies.append(
            {
                "ref": "zadig",
                "dependsOn": ["libwdi"],
            }
        )

    for item in BUNDLED_COMPONENTS:
        matched = sorted(set(assignments[item["bom_ref"]]))
        if matched:
            dependencies.append(
                {
                    "ref": item["bom_ref"],
                    "dependsOn": matched,
                }
            )

    dependency_map: dict[str, set[str]] = {}
    for dependency in dependencies:
        ref = dependency["ref"]
        dependency_map.setdefault(ref, set()).update(dependency.get("dependsOn", []))

    dependencies = [
        {
            "ref": ref,
            "dependsOn": sorted(children),
        }
        for ref, children in sorted(dependency_map.items())
    ]

    metadata: dict[str, Any] = {
        "component": root_component,
        "properties": [
            prop(
                "hazard3-doom:sbom-generation-policy",
                (
                    "Do not invent missing versions or provenance. "
                    "Regenerate for releases and replace unresolved fields "
                    "when exact artifacts are known."
                ),
            ),
            prop(
                "hazard3-doom:generator",
                "scripts/generate-sbom.py",
            ),
        ],
    }
    if epoch is not None:
        metadata["timestamp"] = iso_timestamp(epoch)

    bom: dict[str, Any] = {
        "$schema": CYCLONEDX_SCHEMA,
        "bomFormat": "CycloneDX",
        "specVersion": CYCLONEDX_SPEC_VERSION,
        "version": 1,
        "metadata": metadata,
        "components": components,
        "dependencies": sorted(
            dependencies,
            key=lambda dependency: dependency["ref"],
        ),
        "compositions": [
            {
                "aggregate": "unknown",
                "assemblies": ["hazard3-doom"],
            }
        ],
    }

    return bom


def validate_bom(bom: dict[str, Any]) -> None:
    if bom.get("bomFormat") != "CycloneDX":
        raise RuntimeError("Invalid bomFormat.")

    if bom.get("specVersion") != CYCLONEDX_SPEC_VERSION:
        raise RuntimeError("Unexpected CycloneDX specVersion.")

    serial = bom.get("serialNumber")
    if serial is not None:
        if not isinstance(serial, str) or not serial.startswith("urn:uuid:"):
            raise RuntimeError("serialNumber is not a UUID URN.")

    all_components = [bom["metadata"]["component"], *bom.get("components", [])]
    refs: set[str] = set()

    for component in all_components:
        bom_ref = component.get("bom-ref")
        if not bom_ref:
            raise RuntimeError(
                f"Component {component.get('name', '<unnamed>')} has no bom-ref."
            )
        if bom_ref in refs:
            raise RuntimeError(f"Duplicate bom-ref: {bom_ref}")
        refs.add(bom_ref)

        for digest in component.get("hashes", []):
            if digest.get("alg") != "SHA-256":
                raise RuntimeError(
                    f"Unsupported hash algorithm on {bom_ref}: "
                    f"{digest.get('alg')}"
                )
            content = digest.get("content", "")
            if not re.fullmatch(r"[0-9a-fA-F]{64}", content):
                raise RuntimeError(f"Invalid SHA-256 value on {bom_ref}.")

    dependency_refs: set[str] = set()
    for dependency in bom.get("dependencies", []):
        ref = dependency.get("ref")
        if ref not in refs:
            raise RuntimeError(f"Dependency ref does not exist: {ref}")
        if ref in dependency_refs:
            raise RuntimeError(f"Duplicate dependency ref: {ref}")
        dependency_refs.add(ref)
        for child in dependency.get("dependsOn", []):
            if child not in refs:
                raise RuntimeError(
                    f"Dependency target does not exist: {ref} -> {child}"
                )


def encoded_bom(bom: dict[str, Any]) -> str:
    return json.dumps(
        bom,
        indent=2,
        sort_keys=False,
        ensure_ascii=True,
    ) + "\n"


def resolve_output_path(
    repo: Path,
    requested: Path | None,
    release: bool,
    allow_outside_repo: bool,
) -> Path:
    if requested is None:
        raw = repo / ("build/bom.json" if release else "bom.json")
    elif requested.is_absolute():
        raw = requested
    else:
        raw = repo / requested

    if raw.is_symlink():
        raise RuntimeError(f"Refusing to use symlink as output: {raw}")

    resolved = raw.parent.resolve(strict=False) / raw.name
    repo_resolved = repo.resolve()
    if not allow_outside_repo and not path_is_within(resolved, repo_resolved):
        raise RuntimeError(
            "Output path resolves outside the repository. "
            "Use --allow-output-outside-repo to permit this explicitly."
        )

    return resolved


def atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise RuntimeError(f"Refusing to overwrite symlink: {path}")

    existing_mode: int | None = None
    if path.exists():
        existing_mode = path.stat().st_mode & 0o777

    temp_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as stream:
            temp_name = stream.name
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())

        temp_path = Path(temp_name)
        if existing_mode is not None:
            os.chmod(temp_path, existing_mode)
        elif os.name != "nt":
            os.chmod(temp_path, 0o644)

        os.replace(temp_path, path)
        temp_name = None
    finally:
        if temp_name is not None:
            try:
                Path(temp_name).unlink()
            except FileNotFoundError:
                pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate the Hazard3-Doom CycloneDX SBOM."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help=(
            "Output path. Default: <repo>/bom.json; with --release: "
            "<repo>/build/bom.json."
        ),
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the existing output differs from generated content.",
    )
    parser.add_argument(
        "--release",
        action="store_true",
        help=(
            "Generate an exact-HEAD release SBOM. Requires a clean working "
            "tree and defaults to <repo>/build/bom.json."
        ),
    )
    parser.add_argument(
        "--allow-incomplete",
        action="store_true",
        help="Allow missing required Git provenance instead of failing.",
    )
    parser.add_argument(
        "--allow-output-outside-repo",
        action="store_true",
        help="Allow --output to resolve outside the repository.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        repo = find_repo_root(Path.cwd())
        output = resolve_output_path(
            repo,
            args.output,
            args.release,
            args.allow_output_outside_repo,
        )

        if args.release:
            excluded_paths: tuple[Path, ...] = ()
            if not git_path_tracked(repo, output):
                excluded_paths = (output,)
            if git_dirty(repo, excluded_paths=excluded_paths):
                raise RuntimeError(
                    "Release SBOM requires a clean working tree. "
                    "Commit, stash, or discard unrelated changes first."
                )

        bom = build_bom(repo, args.release, args.allow_incomplete)
        validate_bom(bom)
        text = encoded_bom(bom)

        if args.check:
            if not output.exists():
                print(f"ERROR: {output} does not exist.", file=sys.stderr)
                return 1

            existing = output.read_text(encoding="utf-8")
            if existing != text:
                print(
                    f"ERROR: {output} is not up to date. "
                    "Run scripts/generate-sbom.py.",
                    file=sys.stderr,
                )
                return 1

            print(f"PASS: {output} is up to date.")
            return 0

        atomic_write_text(output, text)

        file_count = sum(
            1 for component in bom["components"]
            if component.get("type") == "file"
        )

        print(f"Wrote: {output}")
        print(f"CycloneDX: {bom['specVersion']}")
        print(f"Mode: {'release' if args.release else 'checked-in'}")
        if args.release:
            print(f"Source revision: {git_head(repo)}")
        print(f"Bundled files hashed: {file_count}")
        print(f"Components: {len(bom['components']) + 1}")
        print("Validation: PASS")
        return 0

    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
