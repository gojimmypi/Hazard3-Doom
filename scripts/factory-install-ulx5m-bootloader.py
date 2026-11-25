#!/usr/bin/env python3
"""Guarded first-time ULX5M-GS bootloader and secondary installation."""

import hashlib
import os
import platform
import pathlib
import shutil
import subprocess
import sys

if not __debug__:
    raise RuntimeError("Do not run with Python optimization enabled")
root = pathlib.Path(__file__).resolve().parent.parent
# Match the WSL detection used by scripts/start-openocd.sh.
is_wsl = sys.platform == "linux" and (
    bool(os.environ.get("WSL_DISTRO_NAME"))
    or bool(os.environ.get("WSL_INTEROP"))
    or "microsoft" in platform.release().lower()
)

if sys.platform == "win32":
    environment = "Windows"
    loader = root / "bin/openFPGALoader.exe"
elif is_wsl:
    environment = "Ubuntu/Linux under WSL (Windows JTAG)"
    loader = root / "bin/openFPGALoader.exe"
    if not shutil.which("wslpath"):
        sys.exit("ERROR: WSL requires wslpath for Windows JTAG file paths.")
    if not (os.environ.get("WSL_INTEROP")
            or pathlib.Path("/proc/sys/fs/binfmt_misc/WSLInterop").exists()
            or shutil.which("cmd.exe")):
        sys.exit("ERROR: Windows interoperability is unavailable in WSL.")
    # Keep flash images and backups on a Windows-mounted drive.
    windows_root = subprocess.check_output(
        ["wslpath", "-w", str(root)], text=True
    ).strip()
    if not (len(windows_root) >= 3 and windows_root[0].isascii()
            and windows_root[0].isalpha() and windows_root[1:3] == ":\\"):
        sys.exit("ERROR: Under WSL, use a repository on a Windows drive (e.g. /mnt/c).")
elif sys.platform == "linux":
    environment = "Native Linux"
    native_loader = shutil.which("openFPGALoader")
    if not native_loader:
        sys.exit("ERROR: Native openFPGALoader not found on PATH.")
    loader = pathlib.Path(native_loader)
else:
    sys.exit(f"ERROR: Unsupported platform: {sys.platform}")

if not loader.is_file():
    sys.exit(f"ERROR: openFPGALoader not found: {loader}")
loader = str(loader)
print(f"Environment: {environment}", flush=True)
print(f"Executable:  {loader}", flush=True)
expected_version = "openFPGALoader v1.2.0"
try:
    actual_version = subprocess.check_output(
        [loader, "--version"], stderr=subprocess.STDOUT, text=True
    ).strip()
except (OSError, subprocess.CalledProcessError) as exc:
    sys.exit(f"ERROR: Cannot execute {loader}: {exc}")
print(f"Version:     {actual_version}", flush=True)
if actual_version != expected_version:
    sys.exit(f"ERROR: Unsupported openFPGALoader version. Expected: {expected_version}")


write_attempted = False


def stop(message, hardware_hint=False):
    print(f"\nERROR: {message}", file=sys.stderr)
    if hardware_hint:
        print("Check the ULX5M and Tigard connections and power.\n"
              "With both powered off, set both SW1 switches ON.\n"
              "Power the ULX5M first, then the Tigard.\n"
              "Check that no other application is using the Tigard.", file=sys.stderr)
    if write_attempted:
        print("A flash write was attempted. Flash contents may have changed.\n"
              "Keep all backups; do not restart blindly.", file=sys.stderr)
    else:
        print("No flash programming was attempted.", file=sys.stderr)
    sys.exit(1)


def jtag(*args):
    # Only pathlib.Path arguments are filenames; options and offsets are not.
    # wslpath also handles output files that do not exist yet.
    command = [loader, "-c", "tigard", "--freq", "1000k"]
    for arg in args:
        if is_wsl and isinstance(arg, pathlib.Path):
            command.append(subprocess.check_output(
                ["wslpath", "-w", str(arg)], text=True
            ).strip())
        else:
            command.append(str(arg))
    print(f"\n[JTAG] {subprocess.list2cmdline(command)}", flush=True)
    try:
        result = subprocess.run(command, check=False,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, errors="replace")
    except OSError as exc:
        stop(f"Cannot run openFPGALoader: {exc}", hardware_hint=True)
    print(result.stdout, end="" if result.stdout.endswith("\n") else "\n", flush=True)
    if result.returncode != 0:
        stop(f"openFPGALoader exited with status {result.returncode} during {args[0]}.",
             hardware_hint=True)
    return result.stdout.lower()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read_bitstream(relative_path, maximum_size):
    path = root / relative_path
    try:
        data = path.read_bytes()
    except OSError as exc:
        sys.exit(f"ERROR: Cannot read {relative_path}: {exc}")
    if not 0 < len(data) <= maximum_size:
        sys.exit(f"ERROR: Invalid bitstream size for {relative_path}: {len(data)} bytes")
    if data[:4] != bytes.fromhex("d901ed96"):
        sys.exit(f"ERROR: Invalid GateMate bitstream header: {relative_path}")
    return data


def verify_release_hash(relative_path, data):
    # Match inventory.sh: two spaces separate the hash and the filename,
    # and filenames are relative to the directory containing the manifest.
    manifest = root / "bin/INVENTORY.sha256"
    name = (root / relative_path).relative_to(manifest.parent).as_posix()
    try:
        lines = manifest.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        sys.exit(f"ERROR: Cannot read {manifest}: {exc}. No flash operations attempted.")

    matches = []
    for line in lines:
        recorded_hash, separator, recorded_name = line.partition("  ")
        if separator and recorded_name == name:
            matches.append(recorded_hash)

    if len(matches) != 1:
        sys.exit(f"ERROR: Expected exactly one entry for {name} in bin/INVENTORY.sha256; "
                 f"found {len(matches)}. No flash operations attempted.")

    expected = matches[0].lower()
    if len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
        sys.exit(f"ERROR: Invalid SHA-256 for {name} in bin/INVENTORY.sha256. "
                 "No flash operations attempted.")

    actual = sha(data)
    print(f"\nFile:      {relative_path}")
    print(f"Size:      {len(data)} bytes")
    print(f"Inventory: {expected}")
    print(f"Current:   {actual}")
    if expected != actual:
        sys.exit(f"ERROR: File SHA-256: DIFFERENT ({relative_path} does not match "
                 "bin/INVENTORY.sha256). No flash operations attempted.")
    print(f"File SHA-256: SAME ({relative_path} matches bin/INVENTORY.sha256)")


def stage(number, message):
    print(f"\n=== Step {number}/7: {message} ===", flush=True)


stage(1, "Verify local installation bitstreams (no hardware writes)")
primary_path = "bin/ulx5m_gs_bootloader.bit"
secondary_path = "bin/ulx5m_gs_blinky.bit"
primary = read_bitstream(primary_path, 0x80000)
secondary = read_bitstream(secondary_path, 0x1ff000)
verify_release_hash(primary_path, primary)
verify_release_hash(secondary_path, secondary)
stage(2, "Detect ULX5M over JTAG (read-only)")
print("Hardware: both SW1 switches ON; power ULX5M first, then Tigard.", flush=True)
if "0x20000001" not in jtag("--detect"):
    stop("Expected GateMate JTAG ID 0x20000001 not found.", hardware_hint=True)
folder = root / "ulx5m-factory-backup"
try:
    folder.mkdir()  # refuses to overwrite an existing session
except FileExistsError:
    stop(f"Backup folder already exists: {folder}\n"
         "Rename or move the previous backup folder before retrying. "
         "Do not delete original factory backups.")
except OSError as exc:
    stop(f"Cannot create backup folder {folder}: {exc}")

def dump(name):
    data = bytearray()
    print(f"[READ] ULX5M SPI flash -> {folder / name} (4 MiB, 32 chunks)", flush=True)
    for offset in range(0, 0x400000, 0x20000):
        chunk = folder / (name + ".chunk")
        log = jtag("--dump-flash", "--file-size", 0x20000, "-o", offset, chunk)
        if "read flash fail" in log or "read id failed" in log:
            stop(f"SPI flash read failed at offset 0x{offset:06X}. "
                 "JTAG detection alone does not confirm SPI flash access.\n"
                 f"Incomplete backup directory retained: {folder}", hardware_hint=True)
        if "read flash jedec id: 0x1f4216" not in log:
            stop(f"Expected SPI flash JEDEC ID 0x1F4216 not confirmed at offset "
                 f"0x{offset:06X}. Backup stopped.\n"
                 f"Incomplete backup directory retained: {folder}", hardware_hint=True)
        try:
            part = chunk.read_bytes()
        except OSError as exc:
            stop(f"Cannot read backup chunk {chunk}: {exc}")
        if len(part) != 0x20000:
            stop(f"Incomplete flash read at offset 0x{offset:06X}: "
                 f"expected 131072 bytes, received {len(part)} bytes.")
        data.extend(part)
        chunk.unlink()
        print(f"[READ] {name}: {len(data) // 0x20000}/32 chunks; "
              f"{len(data)}/{0x400000} bytes", flush=True)
    (folder / name).write_bytes(data)
    print(f"[SAVED] {name}: {len(data)} bytes; SHA-256 {sha(data)}", flush=True)
    return bytes(data)

stage(3, "Back up existing SPI flash twice (read-only)")
print("These backups preserve the original flash; they will NOT be programmed back.", flush=True)
original = dump("factory-a.bin")
if original != dump("factory-b.bin"):
    stop("Factory backups differ. Keep both backups and investigate before retrying.")
print("[PASS] Both original full-chip backups match byte for byte.", flush=True)
stage(4, "Prepare NEW installation images and authorize flash programming")
# Pad only the primary partition and the secondary's final erase sector.
primary = primary.ljust(0x80000, b"\xff")
secondary = secondary.ljust((len(secondary) + 4095) // 4096 * 4096, b"\xff")
expected = bytearray(original)
expected[:len(primary)] = primary
expected[0x201000:0x201000 + len(secondary)] = secondary
images = [
    (0, primary, primary_path, "install-bootloader.bin", "SERV bootloader"),
    (0x201000, secondary, secondary_path, "install-blinky.bin", "Blinky application"),
]
for offset, payload, source, name, description in images:
    path = folder / name
    path.write_bytes(payload)
    print(f"[PREPARE] {source} -> {path}", flush=True)
    print(f"          {description}: {len(payload)} bytes including 0xFF padding", flush=True)
    print(f"          Flash payload: 0x{offset:06X}..0x{offset + len(payload) - 1:06X}", flush=True)

if original == expected:
    print("[INFO] Existing flash already matches both intended installation images.\n"
          "Continuing will still erase and reprogram the same data.", flush=True)
print("\nThe next steps ERASE and WRITE persistent SPI flash using the NEW installation images.\n"
      "The original factory-a.bin and factory-b.bin backups will remain on this computer.\n"
      "Flash erase granularity may extend beyond the payload; full-chip readback checks preservation.\n"
      "Do not disconnect power or JTAG during programming or verification.", flush=True)
if input("Type INSTALL-ULX5M to program the NEW bootloader and Blinky images: ") != "INSTALL-ULX5M":
    stop("Installation cancelled; factory backups retained.")
for offset, payload, source, name, description in images:
    path = folder / name
    if offset == 0:
        stage(5, "Program NEW persistent SERV bootloader, then verify full flash")
    else:
        stage(6, "Program NEW Blinky application, then verify full flash")
    print(f"[WRITE] {path} -> ULX5M SPI flash at 0x{offset:06X}", flush=True)
    print(f"        Source: {source}; {len(payload)} bytes including padding.\n"
          "        Erasing/programming now; programmer output follows when the command returns.", flush=True)
    write_attempted = True
    jtag("-f", "-o", offset, path)
    # Verify the entire chip before proceeding to another write.
    print(f"[VERIFY] Read back all 4 MiB after programming {description}.", flush=True)
    if offset == 0:
        intermediate = primary + original[len(primary):]
        if dump("after-primary.bin") != intermediate:
            stop("Primary verification failed. Secondary write not attempted.")
        print("[PASS] Bootloader verified; all other flash bytes match original.", flush=True)
    else:
        if dump("after-secondary.bin") != expected:
            stop("Final full-chip verification failed.")
        print("[PASS] Both installed images verified; unrelated flash bytes unchanged.", flush=True)
stage(7, "Flash installation complete")
print("PASS: full flash verified; original backups retained", flush=True)
print(f"Backups: {folder / 'factory-a.bin'} and {folder / 'factory-b.bin'}", flush=True)
print("Next: power off Tigard and ULX5M, disconnect Tigard, set both SW1 switches OFF.\n"
      "Power on ULX5M and test automatic Blinky boot and BTN2 DFU recovery.\n"
      "These functional tests are not performed by this script.", flush=True)
