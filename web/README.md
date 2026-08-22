# Hazard3-Doom Web Console

A dependency-free static web app for the Hazard3-Doom UART console, H3D image loading, and ULX3S FPGA programming from a Chromium-based browser using Web Serial and WebUSB.

Windows users need to change drivers from default **FTDI** to **WinUSB** to use the WebUSB programmer.

![Zadig FTDI to WinUSB](../docs/images/Zadig-FTDI-to-WinUSB.png)

To change it back to default, find the **`ULX3S`** device in the `Universal Serial Bus devices` in Windows Device Manager.
Click "Update" and allow Windows to search for default drivers. Be sure to disconnect from the Web console when changing drivers.

![Windows set default USB from WinUSB](../docs/images/Windows-set-default-USB-from-WinUSB.png)

## Features

- Program ULX3S ECP5 FPGA SRAM from a `.bit` or `.svf` file through the board's US1 FT231X JTAG interface using WebUSB.
- Probe and verify ECP5 12F/25F/45F/85F JTAG IDCODEs before programming.
- Connect/disconnect using the browser's serial-port picker.
- Enumerate all serial ports already authorized for this site and select which one Reconnect opens.
- Reconnect to the selected previously authorized port.
- Validate and upload packaged `.h3d` Doom images over UART using the monitor H3L handshake, with optional launch after upload.
- Configurable baud rate, data bits, parity, stop bits, and line ending.
- Live UART receive terminal with a bounded 1,000,000-character scrollback buffer.
- Command entry with Up/Down command history.
- RX/TX byte counters and session timer.
- Download the visible terminal contents as a timestamped `.log` file.
- Copy the full UART terminal contents to the clipboard with one click.
- Capture the current indexed HDMI source over UART and download the reconstructed full 1024x600 active display as a timestamped PNG.
- Optional local echo and auto-scroll.
- Viewport-filling desktop layout that keeps the UART command bar visible while the terminal expands to use available space.
- Collapsible Monitor, SAO / I2C, and I2CDriver GUI control sections.
- Prominent links to the Hazard3-Doom GitHub source and Read the Docs site.
- Hazard3-Doom command buttons for:
  - `help`
  - `sao info`
  - `sao scan`
  - `sao recover`
  - `sao gui`
  - `i2c gui`
- Send Enter, Ctrl-C, and a 150 ms serial break.
- One-byte I2CDriver GUI controls for `S`, `P`, `R`, `W`, `X`, `1`, `4`, `H`, `C`, and `Q` without appending a line ending.
- One saved custom command macro.
- No JavaScript packages, framework, build system, backend, or cloud service required.

## Run locally

Web Serial and WebUSB require a secure context. `localhost` is suitable for local development.

From this directory:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000/` in a browser that supports Web Serial.

On Windows, this also works from PowerShell if Python is installed:

```powershell
py -m http.server 8000
```

## GitHub Pages

The files can be served unchanged by GitHub Pages. HTTPS satisfies the secure-context requirement for Web Serial and WebUSB.

A convenient repository layout is:

```text
docs/
    uart/
        index.html
        app.js
        styles.css
```

The app does not send UART or FPGA programming data to a server. JavaScript communicates directly with the devices selected in the browser permission dialogs.

## Doom H3D UART uploader

The collapsible **Doom H3D uploader** loads a packaged `.h3d` Doom image through the same Web Serial connection used by the UART terminal. It does not write the SD card. The resident monitor must be active at its `>` prompt; if Doom is running, stop Doom first and wait for the prompt before starting the upload.

The browser validates the fixed 64-byte `H3D1` package header, format version, CRC32 flag, reserved words, package length, and payload CRC32 before sending anything. It then follows the same H3L handshake as `doom/upload-doom-image.py`:

```text
browser -> l
monitor -> H3L READY\r\n
browser -> 64-byte H3D header
monitor -> header summary
monitor -> H3L DATA\r\n
browser -> raw H3D payload bytes
monitor -> H3L OK ...\r\n
```

The payload is sent in 4096-byte browser writes while the page shows transfer progress. Normal UART command controls and screen-snip capability probes are suspended during the binary transfer so no unrelated byte can be inserted into the H3D payload. The monitor still performs its own header and CRC validation before accepting the image.

**Launch with `j` after upload** is optional and disabled by default. When selected, the browser sends the monitor's raw `j` command only after `H3L OK` is received.

## HDMI screen snip

The **Screen snip** button sends reserved raw control byte `0x1d` to the active Hazard3-Doom display owner. Running Doom and the active I2CDriver GUI respond with a short ASCII header followed by a binary RGB332 palette and indexed source frame. The browser consumes that transfer without placing it in the terminal, reconstructs the FPGA nearest-neighbor scaling, and downloads a 1024x600 PNG.

Before enabling the button, the browser sends capability query byte `0x1c`. A screen-snip provider replies with ACK byte `0x06`. The resident monitor replies with ACK when a retained HDMI frame is available and NAK byte `0x15` only when no capturable frame has been presented yet. A timeout means the active firmware does not implement the capability protocol.

The browser consumes the reserved `0x1c`, `0x1d`, `0x06`, and `0x15` protocol controls rather than rendering them as terminal characters. Hovering the disabled control is passive and only shows the current `title` text; it does not transmit a probe byte. When a NAK changes the capability state, the terminal receives a readable system message instead of an unprintable control glyph.

Once the browser has seen either ACK or NAK, it rechecks capability every two seconds. Running Doom can be captured from the next completed `DG_DrawFrame()`; the I2CDriver GUI can be captured from its current software framebuffer. When Doom exits with Ctrl-X, or the I2CDriver GUI exits normally, the last displayed source frame and palette are copied once into a retained cache in the reserved video SDRAM area. The monitor then serves that retained frame, so Screen snip remains available after returning to the `>` prompt. The resident monitor HDMI test pattern is cached after a successful presentation as well. There is no per-frame cache copy during normal Doom gameplay.

The current UART transfer protocol is:

```text
H3SNIP1 <source-width> <source-height> 1024 600 IDX8 256 <pixel-bytes>\r\n
<256 raw RGB332 palette bytes><source-width * source-height raw index bytes>
```

Supported source sizes are 320x200 and 400x240. At 115200 baud, a 400x240 capture transfers about 96 KiB of binary data, so Doom or the GUI pauses briefly while the UART transfer completes. No screenshot pixels are uploaded to a server.

The retained cache begins at offset `0x00048000` inside the existing reserved video SDRAM region. It stores a committed header, 256-byte RGB332 palette, and up to 96,000 source pixels. A magic value and inverse-magic commit pair prevent the monitor from treating a partially written cache as valid.

## Default UART settings

The initial default is 115200 8-N-1, no flow control, with CR+LF appended to commands. All settings are selectable in the UI and persisted in `localStorage`.

If the Hazard3-Doom monitor expects a different line ending, select LF, CR, or None before sending commands.

## Browser notes

Web Serial is not implemented in every browser. The app checks for `navigator.serial` and displays an error if the API is unavailable.

`navigator.serial.getPorts()` returns ports for which this site already has permission; it is not an unrestricted enumeration of every Windows COM port. Use **Connect** to open the browser picker and grant/select another serial port. The Web Serial API exposes USB VID/PID information to the page but does not provide the Windows `COMx` name, so the authorized-port selector labels ports by position and VID/PID. Only one port is opened by this UART terminal at a time.

Useful references:

- https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API
- https://developer.chrome.com/docs/capabilities/serial
- https://googlechromelabs.github.io/serial-terminal/
- https://github.com/xtermjs/xterm.js/

## Suggested next Hazard3-Doom additions

The terminal transport is intentionally generic. Project-specific features can be layered on top without changing the serial transport, for example:

1. Parse monitor status into cards instead of only showing text.
2. Add SD status/load controls when the exact resident-monitor commands are finalized.
3. Add SAO probe/read/write forms with validated I2C address/register fields.
4. Add a board-health summary that combines monitor status with the new JTAG identification result.
5. Add command profiles for different Hazard3-Doom monitor revisions.
6. Add optional ANSI terminal emulation with xterm.js if the resident monitor begins using cursor-control sequences.

## Retro terminal appearance

The UART console uses a local-only classic terminal font stack and CRT-style green
phosphor treatment. No web font is downloaded. If an IBM/VGA or VT220-style font
is already installed locally it is preferred; otherwise the page falls back to
Lucida Console / Courier New / monospace.

## FPGA web flasher

The page now includes a collapsible **FPGA web flasher** in the Serial connection panel. It is independent of the Hazard3 UART terminal: the UART continues to use Web Serial and the external USB-to-UART adapter, while FPGA programming uses WebUSB and the ULX3S `US1` FT231X interface.

The first implementation deliberately programs **ECP5 SRAM only**. The programmed image runs immediately but is lost when the board loses power. It does not erase or rewrite the ULX3S SPI configuration flash.

### Programming flow

1. Serve the page from HTTPS or `localhost` in current Chrome/Edge.
2. Expand **FPGA web flasher**.
3. Select the Hazard3-Doom `.bit` file built for the target ULX3S FPGA, or a pre-generated `.svf` file.
4. Click **Connect ULX3S USB** and select the FTDI/ULX3S device attached to `US1`.
5. Click **Probe JTAG**. The page recognizes these ECP5 IDCODEs:
   - `0x21111043` - LFE5U-12F
   - `0x41111043` - LFE5U-25F
   - `0x41112043` - LFE5U-45F
   - `0x41113043` - LFE5U-85F
6. Click **Program FPGA SRAM**.

For `.bit` files, the browser extracts the ECP5 IDCODE from the bitstream and converts the image to the same SRAM-programming SVF sequence produced by Project Trellis `tools/bit_to_svf.py`. The programming button probes IDCODE again immediately before programming. If the image target does not match the attached FPGA, the browser refuses to continue. Normal SVF `TDO`/`MASK` comparisons are also enforced while the programming stream executes.

The implementation uses the ULX3S FT231X synchronous bit-bang JTAG mapping used by `fujprog`:

```text
TCK  0x20
TMS  0x40
TDI  0x80
TDO  0x08
```

The WebUSB FTDI transport uses 1 Mbaud synchronous bit-bang mode and a 1 ms latency timer. Each JTAG clock is emitted as TCK-low followed by TCK-high, with TDO samples returned by the synchronous FTDI read path.

### `.bit` and SVF input

The normal path is now to select the built Hazard3-Doom `.bit` file directly. The browser implements the Project Trellis `tools/bit_to_svf.py` conversion internally, including IDCODE extraction, bit reversal, ECP5 configuration setup, status checks, and the 8000-bit maximum SDR chunks.

Pre-generated SVF remains supported for testing and interoperability. Project Trellis can generate the same stream explicitly:

```bash
python3 /path/to/prjtrellis/tools/bit_to_svf.py \
    bin/fpga_ulx3s-121.bit \
    bin/fpga_ulx3s-121.svf
```

Use the exact bitstream that was built for the board being programmed. The browser reads the ECP5 target ID from the bitstream itself and still verifies the physical JTAG ID immediately before programming; it does not guess the FPGA variant from the filename.

### WebUSB / driver notes

WebUSB and Web Serial are separate browser APIs. The existing UART console can remain connected to the external USB-to-UART adapter while the flasher uses ULX3S `US1`.

Close `fujprog`, OpenOCD, `openFPGALoader`, or any other program that owns the ULX3S FTDI interface before connecting the browser. On Windows, direct WebUSB access requires the ULX3S FT231X interface to use the WinUSB driver rather than the normal FTDI VCP/D2XX driver. Changing that binding makes tools that expect the normal FTDI/D2XX driver unavailable until the driver is changed back.

If Windows returns `Access denied` while opening the selected FT231X, the flasher log detects that condition and tells the user to bind the ULX3S FT231X interface to WinUSB (for example with Zadig), unplug/replug `US1`, and reconnect. If WinUSB is already installed, close other USB/JTAG tools and reconnect the board.

The flasher log has its own vertical scrollbar, can be resized vertically, and normally follows new messages. Uncheck **Auto-scroll** to inspect earlier output without being pulled back to the newest line. **Copy log** copies the complete current flasher log to the clipboard, and **Clear log** removes the displayed flasher history without interrupting an active programming operation.

### Supported SVF subset

The parser implements the subset used by the normal ECP5 SRAM-programming stream:

- `SIR`, `SDR` with `TDI`, optional `TDO`, `MASK`, and all-ones `SMASK`
- `STATE`
- `RUNTEST` with `TCK` and/or `SEC`, plus optional `ENDSTATE`
- `ENDIR` (`IRPAUSE` or `IDLE`)
- `ENDDR` (`DRPAUSE` or `IDLE`)
- zero-length `HIR`, `HDR`, `TIR`, and `TDR`
- `FREQUENCY` as a hint (ignored because the FT231X rate is fixed by the browser transport)
- non-driving `TRST OFF`, `TRST Z`, and `TRST ABSENT`

Unsupported commands stop programming with an explicit error instead of being silently ignored.

### Why persistent SPI flash is not enabled yet

A browser write to configuration flash is persistent and therefore has a larger failure cost than loading FPGA SRAM. The UI intentionally stops at temporary SRAM programming until the WebUSB/JTAG path has been exercised on both the ULX3S 12F and 85F boards. After that validation, persistent flash can be added as a second, separately confirmed workflow rather than overloading the safe temporary-program button.

Implementation references:

- ULX3S manual/programming documentation: https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md
- fujprog FT231X/JTAG implementation: https://github.com/kost/fujprog
- Project Trellis: https://github.com/YosysHQ/prjtrellis
- FTDI synchronous bit-bang behavior: https://www.ftdichip.com/Support/Knowledgebase/synchronousbitbangmode.htm
- WebUSB API: https://developer.mozilla.org/en-US/docs/Web/API/WebUSB_API
