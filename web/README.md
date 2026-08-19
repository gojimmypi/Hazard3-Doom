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
- Optional local echo and auto-scroll.
- Hazard3-Doom command buttons for:
  - `help`
  - `sao info`
  - `sao scan`
  - `sao recover`
  - `sao gui`
  - `i2c gui`
- Send Enter, Ctrl-C, and a 150 ms serial break.
- One-byte I2CDriver GUI controls for `S`, `P`, `R`, `W`, `X`, `1`, `4`, `C`, and `Q` without appending a line ending.
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
