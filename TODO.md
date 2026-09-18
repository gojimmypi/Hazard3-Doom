# To Do

Features and improvements planned and/or in progress for the v0.3.0 release.

## v0.2.0 regression baseline

Preserve the working v0.2.0 behavior while making v0.3.0 changes.

ULX4M-LD baseline verified on 2026-09-20:

- 64 MiB LiteDRAM initialization reports ready.
- Full SDRAM qualification passes, including the sparse 64 MiB alias test and pseudorandom bank tests.
- FPGA/monitor build identity reports `build_match=YES`.
- SDHC/SDXC hot reinsertion followed by `b` successfully initializes and mounts FAT32.
- `DOOM.IMG` loads and validates from SD.
- `DOOM.WAD` loads and validates from SD.
- Doom starts from SDRAM and reaches `Doom interactive HDMI loop: READY`.
- Manual `f` presents the RGB332 test pattern and Screen Snip then succeeds.

Use this as an end-to-end ULX4M-LD regression target for v0.3.0.

# HDMI Startup Diagnostics

Add an FPGA-only HDMI diagnostic pattern that works without Hazard3, monitor firmware, or SDRAM.

- Present the RTL diagnostic pattern immediately after FPGA configuration.
- Keep the diagnostic path independent of CPU, monitor, SDRAM, and Doom.
- Allow the monitor/framebuffer output to replace the startup pattern once software is ready.
- Keep the manual `f` command for rewriting/presenting the monitor RGB332 test frame.
- Make the distinction between HDMI timing activity and an actually presented framebuffer clear in status output.

## Screen Snip behavior

- Keep the duplicate-suppression fix for repeated "Screen snip unavailable" polling results.
- Do not spam the serial terminal from automatic Screen Snip capability polling.
- Prefer showing automatic availability state in the Screen Snip UI itself.
- If the user explicitly requests a Screen Snip and no capturable framebuffer exists, report a concise error.
- Reset the no-frame notification state after a capturable frame becomes available.

# Monitor and Status Cleanup

## SDRAM status reporting

- Report `NOT RUN`, not `FAIL`, when an SDRAM diagnostic has never executed.
- Keep `external_memory_ready`, LiteDRAM initialization state, PLL lock, user-clock readiness, and Wishbone error state visible.
- Require all SDRAM consumers to refuse operation when external memory is not ready:
  - `l` Doom image upload
  - `w` IWAD upload
  - `j` launch/restart
  - `b` SD boot
  - destructive SDRAM diagnostics
  - other heap/SDRAM operations as appropriate
- Preserve the heap-overlap protection that requires `z` before destructive qualification when the active heap overlaps the test region.

## Doom launch diagnostics

- Add a specific reason for launch failures instead of only incrementing `launch_failures`.
- Example reasons include `NO_IWAD`, `NO_IMAGE`, and `SDRAM_NOT_READY`.
- Keep image CRC, backup CRC, load address, entry point, and BSS information visible.

## Heap diagnostics

- Distinguish expected allocation failures used by a boundary/stress test from genuine allocator failures.
- Avoid making an intentionally rejected allocation look like a runtime heap failure.

## Runtime build information

- Remove stale or hard-coded clock/profile strings from Doom diagnostics.
- The monitor reports ULX4M-LD as 64m/40MHz, while Doom currently prints `performance mode: 50 MHz CPU`.
- Derive clock, memory profile, and related build information from one authoritative build/monitor ABI source.

# SD Card and Boot Flow

- Preserve `b` as the complete SD boot path:
  - initialize card
  - mount FAT
  - load Doom image
  - load IWAD
  - validate both
  - launch Doom
- Support SD-card removal/reinsertion while the monitor remains running.
- Add a non-launching SD initialize/rescan operation so a newly inserted card can be tested without immediately launching Doom.
- Consider either a dedicated `sd init` / `sd rescan` command or extending `c` while keeping status-only behavior unambiguous.
- Make SD status distinguish clearly between:
  - not attempted
  - initialized
  - mounted
  - initialization failure
  - FAT mount failure
  - image/WAD file failure
- Continue regression testing SDHC/SDXC FAT32 media and hot reinsertion.

# ESP32 Programming RTL and SD Ownership

Integrate `esp32_prog_ctrl.v` and SD bus arbitration so Hazard3 can safely take and release SD-card ownership on ULX3S.

- Control ESP32 EN/reset and GPIO0 boot/program mode.
- Allow the FPGA to reset/disable the ESP32 before claiming the shared SD bus.
- Release the SD bus cleanly before restarting/releasing the ESP32.
- Preserve the intended J3 hardware override behavior:
  - J3 ON: ESP32 control
  - J3 OFF: FPGA control
- Prevent FPGA and ESP32 from driving the SD signals at the same time.
- Document the ownership sequence and recovery behavior.

# ULX4M / DDR3

- Preserve the working 64 MiB LiteDRAM path as a regression target.
- Continue runtime controller/build identity reporting.
- Continue investigation of practical runtime identification of installed DDR3 where feasible, including Micron vs Alliance devices.
- Test supported LiteDRAM CPU/configuration combinations after toolchain changes.

# Fix RTL Causing Pinned ULX4M Bootloader Build Failure

See [commit f12d091b](https://github.com/gojimmypi/Hazard3-Doom/commit/f12d091bd57ec38729d86c47697abf27889f28cb#diff-e526455223a9dc08040f54ac4a5a2206ad28f44724240db3847bc14bb6c66c63) and the prior failing [workflow](https://github.com/ulx3s/Hazard3-Doom/actions/runs/35130997354/workflow).

Clean up input-only `TRELLIS_IO` instances so they do not drive unnecessary `.I` or `.T` connections.

Current pattern to revisit in [bootloader/rtl/soc_had_misc.v](https://github.com/ulx3s/Hazard3-Doom/blob/9b4d84b2df1de85969dbe193b145fa8cd9596422/bootloader/rtl/soc_had_misc.v#L185):

```verilog
TRELLIS_IO #(
    .DIR("INPUT")
) btn_io_I[7:0] (
    .B(btn),
    .I(1'b0),
    .T(1'b0),
    .O(btn_io)
);
```

After the RTL cleanup:

- Test against a newer OSS CAD Suite.
- Deliberately advance the pinned OSS CAD Suite payload/version.
- Keep the toolchain version pinned for reproducibility rather than returning to an unpinned moving target.
- Record actual Yosys, nextpnr, ecppack, and related tool versions in CI logs.

# CI and Reproducibility

## Full regression with updated Yosys / OSS CAD Suite

There may be additional RTL/tool compatibility issues similar to the ULX4M bootloader failure.

- Run the full supported board/build matrix after advancing the pinned toolchain.
- Verify all expected `.bit`, `.svf`, monitor ELF, and `.h3img` artifacts are produced and non-empty.
- Keep generated build outputs under the top-level `build/` tree.
- Make frozen netlist/LPF inputs explicit and SHA-verified where route-only jobs depend on them.

## Pin GitHub Actions

- Pin release/build workflow Actions to full commit SHAs rather than movable major-version tags.
- Pin the OSS CAD Suite payload/version separately.
- Continue printing the actual installed tool versions in logs.

## Seed sweep improvements

- Include board and seed range in the workflow/run name.
- Add per-seed timeout protection.
- Support useful concurrency without overwhelming runners.
- Produce CSV/result summaries.
- Emit a concise PASS seed list.
- Record synthesis and route duration per seed.
- Preserve useful artifacts for failed and passing seeds.
- Parameterize board and seed/range cleanly.

# ULX3S Buttons and OLED

## Implement ULX3S button GPIO RTL

- Implement `F1`, `F2`, arrow, and `Reset` buttons as GPIO peripherals so they can be used by Doom and examples.
- Synchronize/debounce inputs as appropriate.
- Expose the GPIOs through the documented peripheral/MMIO interface.

## OLED peripherals

- Implement OLED support.
- Use the OLED for button-state diagnostics initially.
- Consider monitor/version/status information where useful.

# One Universal `.h3img`

The `.h3img` application image is currently board/profile specific in places. Ideally, the FPGA/monitor layer should hide board differences behind the monitor service ABI.

- Move board-specific services and addresses behind the monitor ABI where practical.
- Doom should not need to know whether it is running on ULX3S 12F, ULX3S 85F, or ULX4M-LD.
- Avoid embedding board-specific clock/profile assumptions in the application image.
- Preserve the current `H3I1` / `.h3img` package format unless an ABI change is intentionally versioned.

# SD Naming and Upload Tools

## Document `.h3img` rename to `.img` for SD card

Clarify the distinction between:

- host-side packaged application: `.h3img`
- SD-card filename expected by the monitor, such as `DOOM.IMG`
- IWAD filename expected by the SD boot path, such as `DOOM.WAD`

Do not reintroduce the old `.h3d` package terminology.

## `doom/upload-wad.py` memory profile

Review whether `--memory-profile` should remain a required user argument now that the monitor can report its active profile.

Current usage to revisit:

```text
./doom/upload-wad.py DOOM1.WAD --port COM7 --launch
```

Current parser behavior:

```python
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Upload an IWAD to the Hazard3 ECP5 SDRAM WAD region")
    parser.add_argument("wad", type=pathlib.Path)
    parser.add_argument("--port", required=True)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument(
        "--memory-profile",
        choices=MEMORY_PROFILES,
        required=True,
        help=(
            "must match the monitor build: "
            "64m for ULX3S 85F and ULX4M-LD; "
            "32m for the default ULX3S 12F build and ULX4M-LS"
        ),
    )
```

Prefer querying/validating against the resident monitor where practical rather than requiring the user to duplicate board/profile knowledge.

# Documentation

- Finish APB address-map documentation for each peripheral with standalone source examples.
- Keep Windows PowerShell, Windows `cmd.exe`, and Linux/bash command examples clearly distinguished.
- Keep all supported documentation languages synchronized when command syntax or filenames change.
- Maintain the no-install quick-start path using the web uploader and prebuilt artifacts.
- Maintain the list of images/figures and reliable image-anchor navigation.
- Keep the root `VERSION` file authoritative for generated C/web/docs/release metadata.
- Verify release/tag checks against `v${VERSION}`.

# wolfBoot Example

- Get Doom to boot from a secure bootloader; see [wolfSSL/wolfBoot](https://github.com/wolfSSL/wolfBoot).

# ULX5M

- Add support for [intergalaktik/ulx5m-gs](https://github.com/intergalaktik/ulx5m-gs) using the [GateMate](https://colognechip.com/programmable-logic/gatemate/) FPGA.
- See also [OLIMEX/GateMateA1-EVB](https://github.com/OLIMEX/GateMateA1-EVB).

# Implement UART or OTG Device on ULX3S `US2`

- Investigate using the currently unused `US2` USB connection for UART and/or an OTG/device function.
- Determine whether this can reduce dependence on the current external UART path for image/WAD upload and monitor access.

# Transistor Tester

Make the ULX3S a transistor tester. See:

- https://www.mikrocontroller.net/articles/AVR_Transistortester
- https://github.com/kubi48/TransistorTester-source
- https://github.com/madires/Transistortester-Warehouse
