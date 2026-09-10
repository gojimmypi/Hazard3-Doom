#!/bin/bash
set -euo pipefail

printf '\n=== Git working tree ===\n'
git status --short

printf '\n=== Submodules ===\n'
git submodule status --recursive

printf '\n=== Executable bits ===\n'
./scripts/check-executable.sh 1

printf '\n=== SBOM ===\n'
./scripts/generate-sbom.py

printf '\n=== Inventories ===\n'
./scripts/inventory.sh --check ./scripts/
./scripts/inventory.sh --check ./bin/

printf '\n=== Script validation ===\n'
./scripts/test-scripts.sh

printf '\n=== Verify no unexpected changes ===\n'
git status --short

printf '\nPASS: final publish checks completed successfully.\n'
