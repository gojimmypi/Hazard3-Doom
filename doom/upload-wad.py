#!/usr/bin/env python3
import argparse
import binascii
import pathlib
import struct
import sys
import time

WAD_PACKAGE_MAGIC = 0x31573348
WAD_HEADER_BYTES = 64
MEMORY_PROFILES = {
    "64m": (0x22C00000, 0x23C00000),
    "32m": (0x21000000, 0x21C00000),
}
READY_MARKER = b"H3W READY\r\n"
DATA_MARKER = b"H3W DATA\r\n"
OK_MARKER = b"H3W OK"
ERROR_MARKER = b"H3W ERROR"


def import_serial():
    try:
        import serial
    except ImportError as error:
        raise RuntimeError(
            "pyserial required: python -m pip install pyserial") from error
    return serial


def read_until_any(port, markers: tuple[bytes, ...], timeout_seconds: float) -> bytes:
    deadline = time.monotonic() + timeout_seconds
    received = bytearray()
    while time.monotonic() < deadline:
        chunk = port.read(256)
        if chunk:
            received.extend(chunk)
            if any(marker in received for marker in markers):
                return bytes(received)
        else:
            time.sleep(0.01)
    raise TimeoutError("timed out waiting for WAD loader response")


def validate_name(name: str) -> bytes:
    encoded = name.encode("ascii")
    if len(encoded) < 5 or len(encoded) >= 16:
        raise RuntimeError("WAD name must be 5-15 ASCII characters")
    if not name.lower().endswith(".wad"):
        raise RuntimeError("WAD name must end in .wad")
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    if any(character not in allowed for character in name):
        raise RuntimeError("WAD name may contain only letters, digits, '.', '_' and '-'")
    return encoded + bytes(16 - len(encoded))


def validate_iwad(wad: bytes, wad_base: int, wad_limit: int) -> tuple[int, int]:
    if len(wad) < 12:
        raise RuntimeError("file is shorter than a WAD header")
    if len(wad) > wad_limit - wad_base:
        reserved_mib = (wad_limit - wad_base) // (1024 * 1024)
        raise RuntimeError(
            f"IWAD exceeds the reserved {reserved_mib} MiB SDRAM region")
    identification, lump_count, directory_offset = struct.unpack_from("<4sII", wad, 0)
    if identification != b"IWAD":
        raise RuntimeError("this milestone requires an IWAD file")
    directory_bytes = lump_count * 16
    if lump_count == 0 or directory_offset > len(wad) or \
            directory_bytes > len(wad) - directory_offset:
        raise RuntimeError("IWAD directory is outside the file")
    for index in range(lump_count):
        entry_offset = directory_offset + index * 16
        file_position, lump_bytes = struct.unpack_from("<II", wad, entry_offset)
        if file_position > len(wad) or lump_bytes > len(wad) - file_position:
            raise RuntimeError(f"IWAD lump {index} is outside the file")
    return lump_count, directory_offset


def create_header(wad: bytes, name: bytes, wad_base: int) -> tuple[bytes, int]:
    crc = binascii.crc32(wad) & 0xFFFFFFFF
    header = struct.pack(
        "<8I16s4I",
        WAD_PACKAGE_MAGIC,
        WAD_HEADER_BYTES,
        1,
        1,
        wad_base,
        len(wad),
        crc,
        0,
        name,
        0,
        0,
        0,
        0,
    )
    if len(header) != WAD_HEADER_BYTES:
        raise RuntimeError("internal WAD header size error")
    return header, crc


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Upload an IWAD to the Hazard3 ECP5 SDRAM WAD region")
    parser.add_argument("wad", type=pathlib.Path)
    parser.add_argument("--port", required=True)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument(
        "--memory-profile", choices=MEMORY_PROFILES, default="64m",
        help="must match the monitor build (default: 64m)")
    parser.add_argument("--chunk-size", type=int, default=4096)
    parser.add_argument("--name", help="Doom-visible filename; defaults to the input basename")
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--launch-read-seconds", type=float, default=20.0)
    args = parser.parse_args()
    if args.chunk_size <= 0:
        raise RuntimeError("chunk size must be positive")
    wad_base, wad_limit = MEMORY_PROFILES[args.memory_profile]
    wad = args.wad.read_bytes()
    lump_count, directory_offset = validate_iwad(wad, wad_base, wad_limit)
    visible_name = args.name if args.name is not None else args.wad.name.lower()
    encoded_name = validate_name(visible_name)
    header, crc = create_header(wad, encoded_name, wad_base)
    serial = import_serial()
    print(
        f"Opening {args.port} at {args.baud}; profile={args.memory_profile}, "
        f"load=0x{wad_base:08x}, name={visible_name}, bytes={len(wad)}, "
        f"lumps={lump_count}, directory=0x{directory_offset:08x}, "
        f"CRC32=0x{crc:08x}")
    with serial.Serial(
            args.port, args.baud, timeout=0.1, write_timeout=10.0) as port:
        port.reset_input_buffer()
        port.reset_output_buffer()
        port.write(b"w")
        port.flush()
        text = read_until_any(port, (READY_MARKER,), 10.0)
        sys.stdout.write(text.decode("ascii", errors="replace"))
        sys.stdout.flush()
        start = time.monotonic()
        port.write(header)
        port.flush()
        response = read_until_any(port, (DATA_MARKER, ERROR_MARKER), 10.0)
        sys.stdout.write(response.decode("ascii", errors="replace"))
        sys.stdout.flush()
        if ERROR_MARKER in response:
            return 1
        sent = 0
        while sent < len(wad):
            end = min(sent + args.chunk_size, len(wad))
            port.write(wad[sent:end])
            sent = end
            print(
                f"\rUploading IWAD: {sent}/{len(wad)} "
                f"({sent * 100.0 / len(wad):5.1f}%)",
                end="")
            sys.stdout.flush()
        port.flush()
        print()
        wire_seconds = (WAD_HEADER_BYTES + len(wad)) * 10.0 / args.baud
        response = read_until_any(
            port, (OK_MARKER, ERROR_MARKER), max(20.0, wire_seconds + 20.0))
        sys.stdout.write(response.decode("ascii", errors="replace"))
        sys.stdout.flush()
        if ERROR_MARKER in response:
            return 1
        print(f"IWAD accepted in {time.monotonic() - start:.1f} seconds")
        if args.launch:
            port.write(b"j")
            port.flush()
            deadline = time.monotonic() + args.launch_read_seconds
            while time.monotonic() < deadline:
                chunk = port.read(512)
                if chunk:
                    sys.stdout.write(chunk.decode("ascii", errors="replace"))
                    sys.stdout.flush()
                else:
                    time.sleep(0.01)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, TimeoutError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
