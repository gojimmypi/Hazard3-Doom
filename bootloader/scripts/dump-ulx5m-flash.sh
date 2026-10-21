#!/usr/bin/env bash
set -euo pipefail

# Read the ULX5M-GS AT25QL321 (4 MiB) via Tigard JTAG in 64 KiB chunks.
# Flash is never erased or programmed. Run under WSL with the Windows loader.
# Do not run concurrently with another flash dump.

usage()
{
    cat <<'USAGE'
Usage: dump-ulx5m-flash.sh [--resume CHUNK_DIR] [--output IMAGE] [--verify-only]

No arguments: start a new timestamped backup in bootloader/flash-backups/.
--resume:     reuse correctly sized part-00.bin ... part-63.bin files.
--output:     select output image (default: alongside the chunk directory).
--verify-only: check and assemble existing chunks without accessing hardware;
               requires --resume.

Paths must be relative to the repository root. A completed image is never
replaced unless the newly assembled bytes are identical.
USAGE
}

fail()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd -- "$repo_root"

flash_bytes=4194304
chunk_bytes=65536
chunk_count=64
loader="${OPENFPGALOADER:-./bin/openFPGALoader.exe}"
resume_dir=''
output=''
verify_only=0

while (( $# > 0 )); do
    case "$1" in
    --resume)
        if (( $# < 2 )); then
            fail '--resume requires a chunk directory'
        fi
        resume_dir="$2"
        shift 2
        ;;
    --output)
        if (( $# < 2 )); then
            fail '--output requires a file path'
        fi
        output="$2"
        shift 2
        ;;
    --verify-only)
        verify_only=1
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        fail "unknown option: $1"
        ;;
    esac
done

if (( verify_only == 1 )) && [[ -z "$resume_dir" ]]; then
    fail '--verify-only requires --resume CHUNK_DIR'
fi

if [[ -n "$resume_dir" ]]; then
    chunk_dir="${resume_dir%/}"
    if [[ ! -d "$chunk_dir" ]]; then
        fail "chunk directory not found: $chunk_dir"
    fi
    if [[ -z "$output" ]]; then
        output="$(dirname -- "$chunk_dir")/ulx5m-gs-original-flash.bin"
    fi
else
    backup_root='bootloader/flash-backups'
    mkdir -p -- "$backup_root"
    session_dir="$backup_root/$(date -u +%Y%m%dT%H%M%SZ)-$$"
    chunk_dir="$session_dir/chunks"
    mkdir -p -- "$chunk_dir"
    if [[ -z "$output" ]]; then
        output="$session_dir/ulx5m-gs-original-flash.bin"
    fi
fi

# openFPGALoader.exe is a native Windows binary launched from WSL. Pass
# repository-relative filenames rather than WSL /mnt/c/... absolute paths.
if [[ "$chunk_dir" == /* || "$output" == /* ]]; then
    fail 'chunk and image paths must be relative to the repository root'
fi

if (( verify_only == 0 )) && [[ ! -f "$loader" ]]; then
    fail "openFPGALoader not found: $loader"
fi

output_parent="$(dirname -- "$output")"
if [[ ! -d "$output_parent" ]]; then
    fail "output directory not found: $output_parent"
fi

printf 'ULX5M-GS configuration flash backup (read only)\n'
printf 'Flash size: %d bytes, %d chunks of %d bytes\n' "$flash_bytes" "$chunk_count" "$chunk_bytes"
printf 'Chunk directory: %s\nOutput image: %s\n' "$chunk_dir" "$output"
if (( verify_only == 0 )); then
    printf 'Power sequence after JTAG failure: both off, Tigard first, ULX5M second.\n'
fi

tmp=''
image_tmp=''
cleanup()
{
    if [[ -n "$tmp" ]]; then
        rm -f -- "$tmp"
    fi
    if [[ -n "$image_tmp" ]]; then
        rm -f -- "$image_tmp"
    fi
}
trap cleanup EXIT

for (( i = 0; i < chunk_count; i++ )); do
    offset=$((i * chunk_bytes))
    printf -v part '%s/part-%02d.bin' "$chunk_dir" "$i"

    if [[ -e "$part" ]]; then
        size="$(stat -c %s -- "$part")"
        if (( size != chunk_bytes )); then
            fail "existing chunk is $size bytes (expected $chunk_bytes): $part; inspect or move it before retrying"
        fi
        printf 'Reusing chunk %02d/63 (0x%06X)\n' "$i" "$offset"
        continue
    fi

    if (( verify_only == 1 )); then
        fail "missing chunk: $part"
    fi

    printf 'Reading chunk %02d/63 at offset 0x%06X\n' "$i" "$offset"
    tmp="${part}.tmp.$$"
    if [[ -e "$tmp" ]]; then
        fail "temporary file already exists: $tmp"
    fi
    if ! "$loader" -c tigard --freq 100k \
        --dump-flash --offset "$offset" --file-size "$chunk_bytes" "$tmp"; then
        fail "JTAG dump failed at offset 0x$(printf '%06X' "$offset"); completed chunks are preserved"
    fi
    if [[ ! -f "$tmp" ]]; then
        fail "openFPGALoader did not create: $tmp"
    fi
    size="$(stat -c %s -- "$tmp")"
    if (( size != chunk_bytes )); then
        fail "short or oversized read at offset 0x$(printf '%06X' "$offset"): $size bytes"
    fi
    mv -- "$tmp" "$part"
    tmp=''
done

printf 'All 64 chunks present and correctly sized. Assembling image...\n'
image_tmp="${output}.tmp.$$"
if [[ -e "$image_tmp" ]]; then
    fail "temporary image already exists: $image_tmp"
fi
: > "$image_tmp"
for (( i = 0; i < chunk_count; i++ )); do
    printf -v part '%s/part-%02d.bin' "$chunk_dir" "$i"
    cat -- "$part" >> "$image_tmp"
done
size="$(stat -c %s -- "$image_tmp")"
if (( size != flash_bytes )); then
    fail "assembled image has $size bytes, expected $flash_bytes"
fi

if [[ -e "$output" ]]; then
    if ! cmp -s -- "$image_tmp" "$output"; then
        fail "output already exists and differs: $output; choose --output or move existing file"
    fi
    printf 'Existing image matches all 64 chunks; leaving it unchanged.\n'
else
    mv -- "$image_tmp" "$output"
    image_tmp=''
fi

printf '\nBackup image:\n'
stat -c '%n %s bytes' -- "$output"
sha256sum -- "$output"
printf 'First 32 bytes:\n'
od -An -tx1 -N 32 -- "$output"

# Save a checksum alongside the image. Do not overwrite a different manifest.
checksum_file="${output}.sha256"
checksum_tmp="${checksum_file}.tmp.$$"
( cd -- "$output_parent" && sha256sum -- "$(basename -- "$output")" ) > "$checksum_tmp"
if [[ -e "$checksum_file" ]]; then
    if ! cmp -s -- "$checksum_tmp" "$checksum_file"; then
        rm -f -- "$checksum_tmp"
        fail "checksum manifest exists and differs: $checksum_file"
    fi
    rm -f -- "$checksum_tmp"
else
    mv -- "$checksum_tmp" "$checksum_file"
fi
printf 'Checksum file: %s\n' "$checksum_file"
printf 'For an independent check, make a second fresh backup and compare SHA-256 hashes.\n'
