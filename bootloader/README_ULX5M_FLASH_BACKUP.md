# ULX5M-GS JTAG flash backup and SRAM diagnostics

These scripts are for `bootloader/`, not `bootloader-serv/`. Run them in WSL,
from any directory in this repository. They locate the repository root and
use `bin/openFPGALoader.exe` (native Windows USB access through Tigard).

The ULX5M-GS V005 uses an AT25QL321 configuration flash (4 MiB; JEDEC
`1F 42 16`). The 32-byte and 64 KiB JTAG dumps were verified on hardware. A single
4 MiB `--dump-flash` attempt opened a zero-byte file and stopped; the cause
has not been confirmed. Use 64 KiB chunks until resolved. On 2026-10-18,
two independent full 4 MiB chunked backups completed successfully and matched
byte-for-byte using `cmp`.

## Power-up / recovery

1. If the JTAG connection fails after FPGA SRAM programming, disconnect
   USB power from both Tigard and ULX5M.
2. Reconnect **Tigard first, ULX5M second** (confirmed by the user).
3. Leave the board's SW1 setting in JTAG configuration mode (`CFG_MD = 0xC`).
4. Run the flash reader without loading an FPGA bitstream first.

If `openFPGALoader` returns `Error: no device found`, fully power-cycle
both devices in that order and retry. The electrical cause is unknown.

## One-off read (maximum 64 KiB)

From the repository root:

```bash
./bootloader/scripts/read-ulx5m-flash.sh 0 32 bootloader/flash-first32.bin
./bootloader/scripts/read-ulx5m-flash.sh 0 65536 bootloader/flash-first64k.bin
```

The output must not already exist. The script checks the exit status and
exact output size. It does not erase or program SPI flash.

## Full 4 MiB backup

For a fresh, timestamped capture:

```bash
./bootloader/scripts/dump-ulx5m-flash.sh
```

The script reads 64 chunks of 65,536 bytes, validates every chunk size,
assembles a 4,194,304-byte image, and prints its SHA-256. Completed chunks
are retained for resuming. It also writes an adjacent `.sha256` file (paths inside the manifest are
relative to the image directory). It never overwrites an existing assembled
image with different data.

To resume the **manual loop** used during October 18 bring-up, after the
currently running loop has stopped, use:

```bash
./bootloader/scripts/dump-ulx5m-flash.sh \
    --resume bootloader/flash-backup-chunks \
    --output bootloader/ulx5m-gs-original-flash.bin
```

To check an existing set of chunks and image **without contacting JTAG**:

```bash
./bootloader/scripts/dump-ulx5m-flash.sh \
    --resume bootloader/flash-backup-chunks \
    --output bootloader/ulx5m-gs-original-flash.bin \
    --verify-only
```

Resuming trusts existing 65,536-byte files by size; it cannot establish
that each was obtained from the correct flash address. For stronger
verification, run a **new independent full backup** in a different
session directory and compare its SHA-256 with the first capture.

The previously cross-checked first eight bytes were:

```text
D9 01 ED 96 10 4D D6 00
```

These bytes are a historical reference for the original board image,
not a required signature after flash updates. Both complete verified
4,194,304-byte images had SHA-256:

```text
74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d
```

The second capture was produced by `dump-ulx5m-flash.sh`; its image and
the manual 64-chunk capture compared equal with `cmp`. Keep both verified
original backups outside the repository and do not commit them to Git.

## Load a volatile diagnostic bitstream

```bash
./bootloader/scripts/load-ulx5m-sram.sh \
    bootloader/build-ulx5m-gs/top_ulx5m_gs_flash_data.bit
```

This uses JTAG SRAM programming, not flash programming. It may prevent
subsequent JTAG detection until both Tigard and ULX5M are power-cycled.

No script in this set uses an erase, write-enable, or flash-program option.
Do not run the backup script simultaneously with another backup process.
