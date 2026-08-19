# Hazard3-Doom WebSerial UART Console

A dependency-free static web app for connecting to the Hazard3-Doom UART from a browser using the Web Serial API.

## Features

- Connect/disconnect using the browser's serial-port picker.
- Reconnect to a previously authorized port.
- Configurable baud rate, data bits, parity, stop bits, and line ending.
- Live UART receive terminal with a bounded 1,000,000-character scrollback buffer.
- Command entry with Up/Down command history.
- RX/TX byte counters and session timer.
- Download the visible terminal contents as a timestamped `.log` file.
- Capture the current indexed HDMI source over UART and download the reconstructed full 1024x600 active display as a timestamped PNG.
- Optional local echo and auto-scroll.
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

The **Screen snip** button sends reserved raw control byte `0x1d` to the active Hazard3-Doom display application. Updated Doom and I2CDriver GUI firmware respond with a short ASCII header followed by a binary RGB332 palette and the indexed source frame. The browser consumes that binary transfer without placing it in the terminal, reconstructs the FPGA nearest-neighbor scaling, and downloads a 1024x600 PNG.

Before enabling the button, the browser sends capability query byte `0x1c`. Supported Doom and I2CDriver HDMI screens reply with ACK byte `0x06`. The updated resident monitor replies with NAK byte `0x15`, because the monitor prompt itself does not own a readable software copy of the displayed frame. A timeout means the active firmware does not implement the capability protocol.

Once the browser has seen either ACK or NAK, it rechecks capability every two seconds. This lets the button follow the actual active firmware mode even when Doom or the I2CDriver GUI is entered by a path the web app did not initiate. The browser consumes ACK/NAK bytes instead of displaying them in the terminal. Hovering the disabled control explains whether capture is unavailable on the current screen or whether no capability response was received. A capture click also performs a final capability preflight.

The resident monitor handles `0x1c` before its line-command parser and returns NAK, so capability polling cannot become part of a partially typed `sao` or `i2c` command.

The current protocol is:

```text
H3SNIP1 <source-width> <source-height> 1024 600 IDX8 256 <pixel-bytes>\r\n
<256 raw RGB332 palette bytes><source-width * source-height raw index bytes>
```

At 115200 baud, a 400x240 capture transfers about 96 KiB of binary data, so the game or GUI pauses briefly while the UART transfer completes. No screenshot pixels are uploaded to a server.

The companion firmware changes are in `doom/doomgeneric_hazard3.c` and `src/i2cdriver_hdmi.c` in the integration package. The resident monitor itself does not expose block-RAM readback; capture is therefore handled while Doom or the I2CDriver HDMI GUI owns the display and still has the exact displayed source frame in software.

## Default UART settings

The initial default is 115200 8-N-1, no flow control, with CR+LF appended to commands. All settings are selectable in the UI and persisted in `localStorage`.

If the Hazard3-Doom monitor expects a different line ending, select LF, CR, or None before sending commands.

## Browser notes

Web Serial is not implemented in every browser. The app checks for `navigator.serial` and displays an error if the API is unavailable.

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
