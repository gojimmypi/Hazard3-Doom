# ULX5M-GS PicoRV32 fallback: SERV parallel-test findings

Status: 2026-10-18. Information from the concurrent SERV experiment.
This is a documentation-only handoff. PicoRV32 work remains in
`bootloader/`; SERV development remains in `bootloader-serv/`.
Do not copy SERV RTL, firmware, build products, or the downloaded SERV
checkout into this PicoRV32 tree without an explicit integration decision.

## What the two branches showed

- PicoRV32 combined USB/QSPI configuration in the provided archive:
  `bootloader/build-ulx5m-gs/flash-read-pnr.log` ends at 47.74 MHz,
  FAIL against 48.00 MHz. The later eight-seed timing-only sweep also
  found no passes: 42.60, 46.74, 40.77, 42.96, 43.85, 43.62,
  44.12, and 39.07 MHz. The best sweep result was 46.74 MHz.
  Earlier PicoRV32 configurations produced different results; avoid
  treating these as one identical baseline.
- The isolated SERV build (from the sibling directory) uses 3,916
  GateMate CPE_LT, 1,519 CPE_FF, and 21 RAM_HALF; final routed
  Fmax was 48.35 MHz (PASS at 48.00 MHz, about 0.15 ns slack).
  The critical path now runs from the USB transaction microcode ROM
  through decode/`mc_pc` back to a ROM address rather than through
  the PicoRV32 ALU. Area reduction improved placement/timing but
  has not removed the USB timing bottleneck.
- SERV passed RV32I bus tests and an actual firmware startup simulation
  through modeled UART/LED/USB/SPI registers. On hardware, the JTAG-
  loaded SERV image enumerated over USB. Both designs reuse descriptors,
  so enumeration alone does not identify the CPU. Vendor-control JEDEC
  and flash readback have **not** yet been verified for SERV.

## Shared hardware/debug findings

- This ULX5M is the CCGM1A1 GateMate device; JTAG IDCODE is
  `0x20000001` (Cologne Chip GM1Ax). It is not an ECP5 device.
- Tigard is connected to **Windows**, not native WSL USB. Use the
  native `./bin/openFPGALoader.exe` from WSL at the repository root.
  The working settings were `-c tigard --freq 100k` and `-m` for
  **volatile FPGA SRAM only**. Do not use `-f` (flash program).
  Running the Linux `openFPGALoader` produced
  `open_device: failed to initialize ftdi` before FPGA communication.
  A successful `--detect` does not require a power cycle before a
  subsequent SRAM programming attempt in every case. Intermittent
  re-detection failures after configuration still have no confirmed cause.
- Windows showed `USB\VID_1D50&PID_614B` with status `OK`.
  `DEVPKEY_Device_BusReportedDeviceDesc` was
  `ULX5M-GS FPGA (DFU Probe)`; the cached/driver-side friendly name
  remained `ULX4M-LS FPGA (DFU)`. No ULX4M was connected.
  The device disappeared when the ULX5M was unplugged, confirming
  its physical identity. The inherited VID:PID is for development only.
- Removing ULX5M power destroys a volatile JTAG-loaded image. Always
  reload the intended bitstream before drawing conclusions about which
  CPU implementation is running.
- The original 4 MiB flash backup remains the read-only reference:
  first eight bytes `D9 01 ED 96 10 4D D6 00`, SHA-256
  `74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d`.
  Do not commit board-specific flash dumps.

## Fallback plan

Keep the PicoRV32 sources and build targets independent. If SERV fails
USB control transfers or cannot achieve reliable margin, continue timing
work here on the PicoRV32 ALU and the shared USB microcode path. Do not
interpret successful USB enumeration as proof of JEDEC reads, DFU flash
writes, or reliable operation across voltage/temperature.

Current priority is **read-only vendor USB requests** in
`bootloader-serv/`. Never enable configuration-flash writes during this
comparison; keep both designs reversible with volatile JTAG programming.
