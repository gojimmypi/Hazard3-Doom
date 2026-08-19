"use strict";

const MAX_TERMINAL_CHARS = 1_000_000;
const STORAGE_PREFIX = "hazard3-doom-webserial.";

const state = {
    port: null,
    reader: null,
    readLoopPromise: null,
    keepReading: false,
    rxBytes: 0,
    txBytes: 0,
    connectedAt: null,
    sessionTimer: null,
    commandHistory: [],
    historyIndex: 0,
};

const els = {
    statusDot: document.getElementById("statusDot"),
    connectionStatus: document.getElementById("connectionStatus"),
    portDetails: document.getElementById("portDetails"),
    unsupportedNotice: document.getElementById("unsupportedNotice"),
    connectButton: document.getElementById("connectButton"),
    reconnectButton: document.getElementById("reconnectButton"),
    baudRate: document.getElementById("baudRate"),
    dataBits: document.getElementById("dataBits"),
    parity: document.getElementById("parity"),
    stopBits: document.getElementById("stopBits"),
    lineEnding: document.getElementById("lineEnding"),
    autoScroll: document.getElementById("autoScroll"),
    localEcho: document.getElementById("localEcho"),
    terminal: document.getElementById("terminal"),
    commandForm: document.getElementById("commandForm"),
    commandInput: document.getElementById("commandInput"),
    sendButton: document.getElementById("sendButton"),
    downloadButton: document.getElementById("downloadButton"),
    clearButton: document.getElementById("clearButton"),
    rxCount: document.getElementById("rxCount"),
    txCount: document.getElementById("txCount"),
    sessionTime: document.getElementById("sessionTime"),
    macroInput: document.getElementById("macroInput"),
    macroSendButton: document.getElementById("macroSendButton"),
};

const serialSupported = "serial" in navigator;

function setConnectionUi(connected, detail = "") {
    els.statusDot.classList.toggle("connected", connected);
    els.connectionStatus.textContent = connected ? "Connected" : "Not connected";
    els.connectButton.textContent = connected ? "Disconnect" : "Connect";
    els.commandInput.disabled = !connected;
    els.sendButton.disabled = !connected;
    els.macroSendButton.disabled = !connected;
    document.querySelectorAll(".command-button").forEach((button) => {
        button.disabled = !connected;
    });

    [els.baudRate, els.dataBits, els.parity, els.stopBits].forEach((control) => {
        control.disabled = connected;
    });

    if (detail) {
        els.portDetails.textContent = detail;
    } else if (!connected) {
        els.portDetails.textContent = "No serial port selected.";
    }
}

function appendTerminal(text) {
    if (!text) {
        return;
    }

    const previousLength = els.terminal.textContent.length;
    els.terminal.textContent += text;

    if (previousLength + text.length > MAX_TERMINAL_CHARS) {
        els.terminal.textContent = els.terminal.textContent.slice(-MAX_TERMINAL_CHARS);
    }

    if (els.autoScroll.checked) {
        els.terminal.scrollTop = els.terminal.scrollHeight;
    }
}

function appendSystem(text) {
    appendTerminal(`\n[webserial] ${text}\n`);
}

function lineEndingValue() {
    switch (els.lineEnding.value) {
        case "crlf":
            return "\r\n";
        case "lf":
            return "\n";
        case "cr":
            return "\r";
        default:
            return "";
    }
}

function serialOptions() {
    return {
        baudRate: Number(els.baudRate.value),
        dataBits: Number(els.dataBits.value),
        stopBits: Number(els.stopBits.value),
        parity: els.parity.value,
        flowControl: "none",
        bufferSize: 65_536,
    };
}

function describePort(port) {
    const info = port.getInfo();
    const parts = [`${Number(els.baudRate.value).toLocaleString()} baud`, `${els.dataBits.value}${els.parity.value === "none" ? "N" : els.parity.value[0].toUpperCase()}${els.stopBits.value}`];

    if (info.usbVendorId !== undefined) {
        parts.push(`VID 0x${info.usbVendorId.toString(16).padStart(4, "0")}`);
    }
    if (info.usbProductId !== undefined) {
        parts.push(`PID 0x${info.usbProductId.toString(16).padStart(4, "0")}`);
    }

    return parts.join(" · ");
}

async function readLoop() {
    const decoder = new TextDecoder();

    try {
        while (state.port?.readable && state.keepReading) {
            state.reader = state.port.readable.getReader();

            try {
                while (state.keepReading) {
                    const { value, done } = await state.reader.read();
                    if (done) {
                        break;
                    }
                    if (!value) {
                        continue;
                    }

                    state.rxBytes += value.byteLength;
                    els.rxCount.textContent = state.rxBytes.toLocaleString();
                    appendTerminal(decoder.decode(value, { stream: true }));
                }
            } catch (error) {
                if (state.keepReading) {
                    appendSystem(`Read error: ${error.message}`);
                }
            } finally {
                state.reader.releaseLock();
                state.reader = null;
            }
        }

        const tail = decoder.decode();
        if (tail) {
            appendTerminal(tail);
        }
    } finally {
        if (state.keepReading && state.port) {
            appendSystem("Serial input ended.");
        }
    }
}

async function openPort(port) {
    if (state.port) {
        await disconnect();
    }

    await port.open(serialOptions());
    state.port = port;
    state.keepReading = true;
    state.rxBytes = 0;
    state.txBytes = 0;
    state.connectedAt = Date.now();
    els.rxCount.textContent = "0";
    els.txCount.textContent = "0";
    setConnectionUi(true, describePort(port));
    startSessionTimer();
    saveSettings();
    appendSystem(`Connected: ${describePort(port)}`);
    state.readLoopPromise = readLoop();
    els.commandInput.focus();
}

async function connect() {
    if (!serialSupported) {
        return;
    }

    if (state.port) {
        await disconnect();
        return;
    }

    try {
        const port = await navigator.serial.requestPort();
        await openPort(port);
    } catch (error) {
        if (error.name !== "NotFoundError") {
            appendSystem(`Connect failed: ${error.message}`);
        }
    }
}

async function reconnect() {
    if (!serialSupported || state.port) {
        return;
    }

    try {
        const ports = await navigator.serial.getPorts();
        if (ports.length === 0) {
            appendSystem("No previously authorized serial port is available. Use Connect first.");
            return;
        }
        if (ports.length > 1) {
            appendSystem(`Found ${ports.length} authorized ports. Use Connect to choose one.`);
            return;
        }
        await openPort(ports[0]);
    } catch (error) {
        appendSystem(`Reconnect failed: ${error.message}`);
    }
}

async function disconnect() {
    if (!state.port) {
        return;
    }

    const port = state.port;
    state.keepReading = false;

    try {
        if (state.reader) {
            await state.reader.cancel();
        }
        if (state.readLoopPromise) {
            await state.readLoopPromise;
        }
        await port.close();
    } catch (error) {
        appendSystem(`Disconnect warning: ${error.message}`);
    } finally {
        state.reader = null;
        state.readLoopPromise = null;
        state.port = null;
        state.connectedAt = null;
        stopSessionTimer();
        setConnectionUi(false);
        appendSystem("Disconnected.");
    }
}

async function writeBytes(bytes, echoText = "") {
    if (!state.port?.writable) {
        appendSystem("Not connected.");
        return false;
    }

    const writer = state.port.writable.getWriter();
    try {
        await writer.write(bytes);
        state.txBytes += bytes.byteLength;
        els.txCount.textContent = state.txBytes.toLocaleString();
        if (els.localEcho.checked && echoText) {
            appendTerminal(echoText);
        }
        return true;
    } catch (error) {
        appendSystem(`Write failed: ${error.message}`);
        return false;
    } finally {
        writer.releaseLock();
    }
}

async function sendText(text, addLineEnding = true) {
    const payload = `${text}${addLineEnding ? lineEndingValue() : ""}`;
    return writeBytes(new TextEncoder().encode(payload), payload);
}

async function sendCommand(command) {
    if (!command && command !== "") {
        return;
    }

    const sent = await sendText(command, true);
    if (!sent || !command.trim()) {
        return;
    }

    const trimmed = command.trim();
    if (state.commandHistory[state.commandHistory.length - 1] !== trimmed) {
        state.commandHistory.push(trimmed);
        if (state.commandHistory.length > 100) {
            state.commandHistory.shift();
        }
    }
    state.historyIndex = state.commandHistory.length;
}

async function sendBreak() {
    if (!state.port) {
        return;
    }

    if (typeof state.port.setSignals !== "function") {
        appendSystem("This browser does not expose setSignals() for break control.");
        return;
    }

    try {
        await state.port.setSignals({ break: true });
        await new Promise((resolve) => setTimeout(resolve, 150));
        await state.port.setSignals({ break: false });
        appendSystem("Sent 150 ms break.");
    } catch (error) {
        appendSystem(`Break failed: ${error.message}`);
    }
}

function clearTerminal() {
    els.terminal.textContent = "";
}

function downloadLog() {
    const now = new Date();
    const stamp = now.toISOString().replaceAll(":", "-").replace(".000Z", "Z");
    const blob = new Blob([els.terminal.textContent], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `hazard3-doom-uart-${stamp}.log`;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
}

function startSessionTimer() {
    stopSessionTimer();
    updateSessionTime();
    state.sessionTimer = window.setInterval(updateSessionTime, 1000);
}

function stopSessionTimer() {
    if (state.sessionTimer !== null) {
        window.clearInterval(state.sessionTimer);
        state.sessionTimer = null;
    }
    els.sessionTime.textContent = "00:00:00";
}

function updateSessionTime() {
    if (!state.connectedAt) {
        return;
    }
    const seconds = Math.floor((Date.now() - state.connectedAt) / 1000);
    const hours = Math.floor(seconds / 3600).toString().padStart(2, "0");
    const minutes = Math.floor((seconds % 3600) / 60).toString().padStart(2, "0");
    const secs = (seconds % 60).toString().padStart(2, "0");
    els.sessionTime.textContent = `${hours}:${minutes}:${secs}`;
}

function saveSettings() {
    const settings = {
        baudRate: els.baudRate.value,
        dataBits: els.dataBits.value,
        parity: els.parity.value,
        stopBits: els.stopBits.value,
        lineEnding: els.lineEnding.value,
        autoScroll: els.autoScroll.checked,
        localEcho: els.localEcho.checked,
        macro: els.macroInput.value,
    };
    localStorage.setItem(`${STORAGE_PREFIX}settings`, JSON.stringify(settings));
}

function loadSettings() {
    try {
        const saved = JSON.parse(localStorage.getItem(`${STORAGE_PREFIX}settings`) || "null");
        if (!saved) {
            return;
        }

        for (const key of ["baudRate", "dataBits", "parity", "stopBits", "lineEnding"]) {
            if (saved[key] !== undefined && els[key]) {
                els[key].value = saved[key];
            }
        }
        if (typeof saved.autoScroll === "boolean") {
            els.autoScroll.checked = saved.autoScroll;
        }
        if (typeof saved.localEcho === "boolean") {
            els.localEcho.checked = saved.localEcho;
        }
        if (typeof saved.macro === "string") {
            els.macroInput.value = saved.macro;
        }
    } catch {
        localStorage.removeItem(`${STORAGE_PREFIX}settings`);
    }
}

function commandHistoryKey(event) {
    if (event.key === "ArrowUp") {
        if (state.commandHistory.length === 0) {
            return;
        }
        event.preventDefault();
        state.historyIndex = Math.max(0, state.historyIndex - 1);
        els.commandInput.value = state.commandHistory[state.historyIndex] || "";
        els.commandInput.setSelectionRange(els.commandInput.value.length, els.commandInput.value.length);
    } else if (event.key === "ArrowDown") {
        if (state.commandHistory.length === 0) {
            return;
        }
        event.preventDefault();
        state.historyIndex = Math.min(state.commandHistory.length, state.historyIndex + 1);
        els.commandInput.value = state.commandHistory[state.historyIndex] || "";
        els.commandInput.setSelectionRange(els.commandInput.value.length, els.commandInput.value.length);
    }
}

function wireEvents() {
    els.connectButton.addEventListener("click", connect);
    els.reconnectButton.addEventListener("click", reconnect);
    els.clearButton.addEventListener("click", clearTerminal);
    els.downloadButton.addEventListener("click", downloadLog);

    els.commandForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        const command = els.commandInput.value;
        els.commandInput.value = "";
        await sendCommand(command);
    });

    els.commandInput.addEventListener("keydown", commandHistoryKey);

    document.querySelectorAll("[data-command]").forEach((button) => {
        button.addEventListener("click", () => sendCommand(button.dataset.command));
    });

    document.querySelectorAll("[data-raw]").forEach((button) => {
        button.addEventListener("click", () => {
            const value = button.dataset.raw;
            writeBytes(new TextEncoder().encode(value), els.localEcho.checked ? value : "");
        });
    });

    document.querySelectorAll("[data-control]").forEach((button) => {
        button.addEventListener("click", async () => {
            switch (button.dataset.control) {
                case "enter":
                    await sendCommand("");
                    break;
                case "ctrl-c":
                    await writeBytes(new Uint8Array([0x03]), els.localEcho.checked ? "^C" : "");
                    break;
                case "ctrl-x":
                    await writeBytes(new Uint8Array([0x18]), els.localEcho.checked ? "^X" : "");
                    break;
                case "break":
                    await sendBreak();
                    break;
                default:
                    break;
            }
        });
    });

    els.macroSendButton.addEventListener("click", () => sendCommand(els.macroInput.value));
    els.macroInput.addEventListener("change", saveSettings);

    for (const control of [els.baudRate, els.dataBits, els.parity, els.stopBits, els.lineEnding, els.autoScroll, els.localEcho]) {
        control.addEventListener("change", saveSettings);
    }

    if (serialSupported) {
        navigator.serial.addEventListener("disconnect", async (event) => {
            const disconnectedPort = event.port || event.target;
            if (disconnectedPort === state.port) {
                appendSystem("Device disconnected by the operating system.");
                await disconnect();
            }
        });
    }

    window.addEventListener("beforeunload", () => {
        saveSettings();
    });
}

async function initialize() {
    loadSettings();
    wireEvents();
    setConnectionUi(false);

    if (!serialSupported) {
        els.unsupportedNotice.classList.remove("hidden");
        els.connectButton.disabled = true;
        els.reconnectButton.disabled = true;
        appendSystem("Web Serial API unavailable in this browser.");
        return;
    }

    try {
        const authorizedPorts = await navigator.serial.getPorts();
        if (authorizedPorts.length === 1) {
            els.portDetails.textContent = "One previously authorized serial port is available. Click Reconnect.";
        } else if (authorizedPorts.length > 1) {
            els.portDetails.textContent = `${authorizedPorts.length} previously authorized serial ports are available. Click Connect to choose one.`;
        }
    } catch (error) {
        appendSystem(`Could not enumerate authorized ports: ${error.message}`);
    }
}

initialize();
