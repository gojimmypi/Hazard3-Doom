# Hazard3-Doom WebSerial UART Console

A dependency-free static web app for connecting to the Hazard3-Doom UART from a browser using the Web Serial API.

## Features

- Connect/disconnect using the browser's serial-port picker.
- Enumerate all serial ports already authorized for this site and select which one Reconnect opens.
- Reconnect to the selected previously authorized port.
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

Web Serial requires a secure context. `localhost` is suitable for local development.

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

The files can be served unchanged by GitHub Pages. HTTPS satisfies the secure-context requirement for Web Serial.

A convenient repository layout is:

```text
docs/
    uart/
        index.html
        app.js
        styles.css
```

The app does not send UART data to a server. JavaScript communicates directly with the serial device selected in the browser permission dialog.

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
4. Add firmware/FPGA identification and board-health summary.
5. Add command profiles for different Hazard3-Doom monitor revisions.
6. Add optional ANSI terminal emulation with xterm.js if the resident monitor begins using cursor-control sequences.

## Retro terminal appearance

The UART console uses a local-only classic terminal font stack and CRT-style green
phosphor treatment. No web font is downloaded. If an IBM/VGA or VT220-style font
is already installed locally it is preferred; otherwise the page falls back to
Lucida Console / Courier New / monospace.
