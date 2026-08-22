"use strict";

const MAX_TERMINAL_CHARS = 1_000_000;
const STORAGE_PREFIX = "hazard3-doom-webserial.";
const SCREEN_SNIP_CAPABILITY_REQUEST_BYTE = 0x1c;
const SCREEN_SNIP_CAPABILITY_ACK_BYTE = 0x06;
const SCREEN_SNIP_CAPABILITY_NAK_BYTE = 0x15;
const SCREEN_SNIP_REQUEST_BYTE = 0x1d;
const SCREEN_SNIP_CAPABILITY_TIMEOUT_MS = 750;
const SCREEN_SNIP_CAPABILITY_WATCH_MS = 2000;
const SCREEN_SNIP_TRANSITION_RETRY_MS = 1000;
const SCREEN_SNIP_TRANSITION_WINDOW_MS = 15000;
const SCREEN_SNIP_TIMEOUT_MS = 30_000;
const SCREEN_SNIP_MAX_SOURCE_PIXELS = 1_000_000;
const SCREEN_SNIP_MAX_DISPLAY_PIXELS = 4_000_000;
const H3D_IMAGE_MAGIC = 0x31443348;
const H3D_HEADER_BYTES = 64;
const H3D_FORMAT_VERSION = 1;
const H3D_FLAG_CRC32 = 1;
const H3D_UPLOAD_CHUNK_BYTES = 4096;
const H3D_READY_MARKER = "H3L READY\r\n";
const H3D_DATA_MARKER = "H3L DATA\r\n";
const H3D_OK_MARKER = "H3L OK";
const H3D_ERROR_MARKER = "H3L ERROR";
const H3D_RESPONSE_TIMEOUT_MS = 10_000;
const H3D_RESULT_MARGIN_MS = 20_000;

const state = {
    port: null,
    authorizedPorts: [],
    reader: null,
    readLoopPromise: null,
    keepReading: false,
    rxBytes: 0,
    txBytes: 0,
    connectedAt: null,
    sessionTimer: null,
    commandHistory: [],
    historyIndex: 0,
    screenSnip: null,
    screenSnipCapability: "unavailable",
    screenSnipCapabilityProtocolKnown: false,
    screenSnipProbe: null,
    screenSnipProbeTimer: null,
    screenSnipWatchTimer: null,
    screenSnipTransitionDeadline: 0,
    h3dImage: null,
    h3dWaiter: null,
    serialOperation: null,
    textDecoder: new TextDecoder(),
};

const els = {
    statusDot: document.getElementById("statusDot"),
    connectionStatus: document.getElementById("connectionStatus"),
    portDetails: document.getElementById("portDetails"),
    unsupportedNotice: document.getElementById("unsupportedNotice"),
    connectButton: document.getElementById("connectButton"),
    reconnectButton: document.getElementById("reconnectButton"),
    authorizedPort: document.getElementById("authorizedPort"),
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
    copyButton: document.getElementById("copyButton"),
    copyButtonLabel: document.getElementById("copyButtonLabel"),
    screenSnipControl: document.getElementById("screenSnipControl"),
    screenSnipButton: document.getElementById("screenSnipButton"),
    h3dFileInput: document.getElementById("h3dFileInput"),
    h3dFileName: document.getElementById("h3dFileName"),
    h3dFileDetails: document.getElementById("h3dFileDetails"),
    h3dUploadButton: document.getElementById("h3dUploadButton"),
    h3dLaunchAfterUpload: document.getElementById("h3dLaunchAfterUpload"),
    h3dProgress: document.getElementById("h3dProgress"),
    h3dProgressLabel: document.getElementById("h3dProgressLabel"),
    clearButton: document.getElementById("clearButton"),
    rxCount: document.getElementById("rxCount"),
    txCount: document.getElementById("txCount"),
    sessionTime: document.getElementById("sessionTime"),
    macroInput: document.getElementById("macroInput"),
    macroSendButton: document.getElementById("macroSendButton"),
};

const serialSupported = "serial" in navigator;

function screenSnipStatusText() {
    if (!state.port) {
        return "Screen snip unavailable: connect to the board first.";
    }
    if (state.screenSnip !== null) {
        return "Screen snip capture is in progress.";
    }
    if (state.serialOperation === "h3d-upload") {
        return "Screen snip is paused while an H3D image is uploading.";
    }
    if (state.screenSnipCapability === "checking") {
        return "Checking whether the active firmware screen supports screen snip.";
    }
    if (state.screenSnipCapability !== "available") {
        if (state.screenSnipCapabilityProtocolKnown) {
            return "Screen snip unavailable: no capturable HDMI frame has been presented yet.";
        }
        return "Screen snip unavailable: the active firmware does not report screen capture support.";
    }
    return "Download the current HDMI display as a full 1024x600 PNG.";
}

function updateScreenSnipUi() {
    const available = state.port &&
        state.serialOperation === null &&
        state.screenSnipCapability === "available" &&
        state.screenSnip === null;
    const status = screenSnipStatusText();

    els.screenSnipButton.disabled = !available;
    els.screenSnipButton.textContent = state.screenSnip !== null ? "Capturing..." : "Screen snip";
    els.screenSnipControl.title = status;
    els.screenSnipButton.setAttribute("aria-label", status);
    updateH3dUploaderUi();
}

function setScreenSnipCapability(capability) {
    state.screenSnipCapability = capability;
    updateScreenSnipUi();
}

function clearScreenSnipProbe(result = false) {
    const probe = state.screenSnipProbe;
    if (!probe) {
        return;
    }
    if (probe.timeoutId !== undefined) {
        window.clearTimeout(probe.timeoutId);
    }
    state.screenSnipProbe = null;
    probe.resolve(result);
}

function cancelScheduledScreenSnipProbe() {
    if (state.screenSnipProbeTimer !== null) {
        window.clearTimeout(state.screenSnipProbeTimer);
        state.screenSnipProbeTimer = null;
    }
}

function stopScreenSnipCapabilityWatch() {
    if (state.screenSnipWatchTimer !== null) {
        window.clearInterval(state.screenSnipWatchTimer);
        state.screenSnipWatchTimer = null;
    }
}

function startScreenSnipCapabilityWatch() {
    if (!state.port || !state.screenSnipCapabilityProtocolKnown ||
        state.screenSnipWatchTimer !== null) {
        return;
    }

    state.screenSnipWatchTimer = window.setInterval(() => {
        if (state.port && state.screenSnip === null &&
            state.screenSnipProbe === null) {
            void probeScreenSnipCapability();
        }
    }, SCREEN_SNIP_CAPABILITY_WATCH_MS);
}

async function probeScreenSnipCapability() {
    if (!state.port?.writable || state.screenSnip !== null ||
        state.serialOperation !== null) {
        return false;
    }
    if (state.screenSnipProbe !== null) {
        return state.screenSnipProbe.promise;
    }

    setScreenSnipCapability("checking");
    let resolveProbe;
    const promise = new Promise((resolve) => {
        resolveProbe = resolve;
    });
    const probe = { timeoutId: undefined, promise, resolve: resolveProbe };
    state.screenSnipProbe = probe;

    const sent = await writeBytes(new Uint8Array([SCREEN_SNIP_CAPABILITY_REQUEST_BYTE]));
    if (state.screenSnipProbe !== probe) {
        return promise;
    }
    if (!sent) {
        clearScreenSnipProbe(false);
        setScreenSnipCapability("unavailable");
        return promise;
    }

    probe.timeoutId = window.setTimeout(() => {
        if (state.screenSnipProbe !== probe) {
            return;
        }
        clearScreenSnipProbe(false);
        if (screenSnipTransitionActive()) {
            continueScreenSnipTransitionProbe();
        } else {
            setScreenSnipCapability("unavailable");
        }
    }, SCREEN_SNIP_CAPABILITY_TIMEOUT_MS);
    return promise;
}

function scheduleScreenSnipProbe(delayMs = 500) {
    if (!state.port || state.screenSnip !== null ||
        state.serialOperation !== null) {
        return;
    }

    cancelScheduledScreenSnipProbe();
    state.screenSnipProbeTimer = window.setTimeout(() => {
        state.screenSnipProbeTimer = null;
        void probeScreenSnipCapability();
    }, delayMs);
}

function screenSnipTransitionActive() {
    return state.screenSnipTransitionDeadline > performance.now();
}

function beginScreenSnipTransitionProbe(delayMs = 500) {
    state.screenSnipTransitionDeadline =
        performance.now() + SCREEN_SNIP_TRANSITION_WINDOW_MS;
    clearScreenSnipProbe();
    setScreenSnipCapability("checking");
    scheduleScreenSnipProbe(delayMs);
}

function continueScreenSnipTransitionProbe() {
    if (!screenSnipTransitionActive()) {
        state.screenSnipTransitionDeadline = 0;
        setScreenSnipCapability("unavailable");
        return;
    }

    setScreenSnipCapability("checking");
    scheduleScreenSnipProbe(SCREEN_SNIP_TRANSITION_RETRY_MS);
}

function formatHex32(value) {
    return `0x${value.toString(16).padStart(8, "0")}`;
}

function crc32(bytes) {
    let crc = 0xffffffff;

    for (const byte of bytes) {
        crc ^= byte;
        for (let bit = 0; bit < 8; ++bit) {
            const mask = -(crc & 1);
            crc = (crc >>> 1) ^ (0xedb88320 & mask);
        }
    }

    return (crc ^ 0xffffffff) >>> 0;
}

function validateH3dPackage(bytes) {
    if (bytes.byteLength < H3D_HEADER_BYTES) {
        throw new Error("file is shorter than the 64-byte H3D header");
    }

    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const words = Array.from({ length: 16 }, (_, index) =>
        view.getUint32(index * 4, true));
    const [magic, headerBytes, formatVersion, flags, loadAddress, imageBytes,
        entryAddress, bssAddress, bssBytes, payloadCrc32] = words;

    if (magic !== H3D_IMAGE_MAGIC) {
        throw new Error("invalid H3D magic; expected H3D1");
    }
    if (headerBytes !== H3D_HEADER_BYTES) {
        throw new Error(`unsupported H3D header size ${headerBytes}`);
    }
    if (formatVersion !== H3D_FORMAT_VERSION) {
        throw new Error(`unsupported H3D format version ${formatVersion}`);
    }
    if (flags !== H3D_FLAG_CRC32) {
        throw new Error(`unsupported H3D flags ${formatHex32(flags)}`);
    }
    if (imageBytes === 0 || bytes.byteLength !== headerBytes + imageBytes) {
        throw new Error("H3D package length does not match its header");
    }
    if (words.slice(10).some((value) => value !== 0)) {
        throw new Error("H3D reserved header words must be zero");
    }

    const payload = bytes.subarray(headerBytes);
    const actualCrc32 = crc32(payload);
    if (actualCrc32 !== payloadCrc32) {
        throw new Error(
            `H3D payload CRC mismatch: expected ${formatHex32(payloadCrc32)}, ` +
            `calculated ${formatHex32(actualCrc32)}`);
    }

    return {
        packageBytes: bytes,
        payload,
        headerBytes,
        imageBytes,
        loadAddress,
        entryAddress,
        bssAddress,
        bssBytes,
        payloadCrc32,
    };
}

function updateH3dUploaderUi() {
    const uploading = state.serialOperation === "h3d-upload";
    const ready = Boolean(state.port && state.h3dImage &&
        state.serialOperation === null && state.screenSnip === null);

    els.h3dFileInput.disabled = uploading;
    els.h3dLaunchAfterUpload.disabled = uploading;
    els.h3dUploadButton.disabled = !ready;
    els.h3dUploadButton.textContent = uploading ? "Uploading..." : "Upload H3D";
}

function setSerialOperation(operation) {
    state.serialOperation = operation;
    setConnectionUi(Boolean(state.port), state.port ? describePort(state.port) : "");
}

function clearH3dWaiter(error = null) {
    const waiter = state.h3dWaiter;
    if (!waiter) {
        return;
    }

    window.clearTimeout(waiter.timeoutId);
    state.h3dWaiter = null;
    if (error) {
        waiter.reject(error);
    }
}

function waitForH3dResponse(markers, timeoutMs, description) {
    if (state.h3dWaiter) {
        return Promise.reject(new Error("another H3D response is already pending"));
    }

    return new Promise((resolve, reject) => {
        const waiter = {
            buffer: "",
            markers,
            resolve,
            reject,
            timeoutId: window.setTimeout(() => {
                if (state.h3dWaiter !== waiter) {
                    return;
                }
                state.h3dWaiter = null;
                reject(new Error(`timed out waiting for ${description}`));
            }, timeoutMs),
        };
        state.h3dWaiter = waiter;
    });
}

function observeH3dResponse(bytes) {
    const waiter = state.h3dWaiter;
    if (!waiter) {
        return;
    }

    waiter.buffer += new TextDecoder("ascii").decode(bytes);
    if (waiter.buffer.length > 8192) {
        waiter.buffer = waiter.buffer.slice(-8192);
    }

    for (const marker of waiter.markers) {
        if (!waiter.buffer.includes(marker)) {
            continue;
        }
        window.clearTimeout(waiter.timeoutId);
        state.h3dWaiter = null;
        waiter.resolve(marker);
        return;
    }
}

async function selectH3dFile() {
    state.h3dImage = null;
    els.h3dFileName.textContent = "No H3D image selected";
    els.h3dFileDetails.textContent = "";
    els.h3dProgress.value = 0;
    els.h3dProgressLabel.textContent = "Idle";

    const file = els.h3dFileInput.files?.[0];
    if (!file) {
        updateH3dUploaderUi();
        return;
    }

    els.h3dFileName.textContent = file.name;
    els.h3dFileDetails.textContent = "Validating package and CRC32...";
    try {
        const bytes = new Uint8Array(await file.arrayBuffer());
        const image = validateH3dPackage(bytes);
        state.h3dImage = { ...image, fileName: file.name };
        els.h3dFileDetails.textContent =
            `${image.imageBytes.toLocaleString()} payload bytes | ` +
            `CRC32 ${formatHex32(image.payloadCrc32)} | ` +
            `load ${formatHex32(image.loadAddress)} | entry ${formatHex32(image.entryAddress)}`;
    } catch (error) {
        els.h3dFileDetails.textContent = `Invalid H3D image: ${error.message}`;
    }

    updateH3dUploaderUi();
}

async function uploadH3dImage() {
    const image = state.h3dImage;
    if (!state.port?.writable) {
        appendSystem("H3D upload requires an open serial connection.");
        return;
    }
    if (!image) {
        appendSystem("Select a valid H3D image first.");
        return;
    }
    if (state.serialOperation !== null || state.screenSnip !== null) {
        appendSystem("Another serial operation is already in progress.");
        return;
    }

    const launchAfterUpload = els.h3dLaunchAfterUpload.checked;
    let uploadSucceeded = false;
    const startedAt = performance.now();

    cancelScheduledScreenSnipProbe();
    stopScreenSnipCapabilityWatch();
    clearScreenSnipProbe();
    setScreenSnipCapability("checking");
    setSerialOperation("h3d-upload");
    els.h3dProgress.value = 0;
    els.h3dProgressLabel.textContent = "Starting monitor loader...";
    appendSystem(
        `H3D upload: ${image.fileName}, payload=${image.imageBytes.toLocaleString()} bytes, ` +
        `CRC32=${formatHex32(image.payloadCrc32)}.`);

    try {
        const readyPromise = waitForH3dResponse(
            [H3D_READY_MARKER, H3D_ERROR_MARKER],
            H3D_RESPONSE_TIMEOUT_MS,
            "H3L READY");
        if (!await writeBytes(new Uint8Array([0x6c]))) {
            clearH3dWaiter();
            throw new Error("could not send the H3D loader command");
        }
        const readyResult = await readyPromise;
        if (readyResult === H3D_ERROR_MARKER) {
            throw new Error("monitor reported an H3L error before receiving the header");
        }

        els.h3dProgressLabel.textContent = "Sending 64-byte header...";
        const dataPromise = waitForH3dResponse(
            [H3D_DATA_MARKER, H3D_ERROR_MARKER],
            H3D_RESPONSE_TIMEOUT_MS,
            "H3L DATA");
        if (!await writeBytes(image.packageBytes.subarray(0, image.headerBytes))) {
            clearH3dWaiter();
            throw new Error("could not send the H3D header");
        }
        const dataResult = await dataPromise;
        if (dataResult === H3D_ERROR_MARKER) {
            throw new Error("monitor rejected the H3D header");
        }

        const wireMs = Math.ceil(
            (image.headerBytes + image.imageBytes) * 10 * 1000 / Number(els.baudRate.value));
        const resultPromise = waitForH3dResponse(
            [H3D_OK_MARKER, H3D_ERROR_MARKER],
            Math.max(H3D_RESULT_MARGIN_MS, wireMs + H3D_RESULT_MARGIN_MS),
            "H3L OK");

        let sent = 0;
        while (sent < image.payload.byteLength) {
            const end = Math.min(sent + H3D_UPLOAD_CHUNK_BYTES, image.payload.byteLength);
            if (!await writeBytes(image.payload.subarray(sent, end))) {
                clearH3dWaiter();
                throw new Error("serial write failed during H3D payload upload");
            }
            sent = end;
            const percent = sent * 100 / image.payload.byteLength;
            els.h3dProgress.value = percent;
            els.h3dProgressLabel.textContent =
                `${sent.toLocaleString()} / ${image.payload.byteLength.toLocaleString()} bytes ` +
                `(${percent.toFixed(1)}%)`;
        }

        const result = await resultPromise;
        if (result === H3D_ERROR_MARKER) {
            throw new Error("monitor reported an H3L upload error; see the UART terminal");
        }

        uploadSucceeded = true;
        els.h3dProgress.value = 100;
        const elapsedSeconds = (performance.now() - startedAt) / 1000;
        els.h3dProgressLabel.textContent = `Accepted in ${elapsedSeconds.toFixed(1)} s`;
        appendSystem(`H3D upload accepted in ${elapsedSeconds.toFixed(1)} seconds.`);

        if (launchAfterUpload) {
            appendSystem("Launching the uploaded Doom image with monitor command j.");
            await writeBytes(new Uint8Array([0x6a]));
        }
    } catch (error) {
        els.h3dProgressLabel.textContent = `Failed: ${error.message}`;
        appendSystem(
            `H3D upload failed: ${error.message}. ` +
            "Make sure the resident monitor prompt is active; stop Doom before retrying.");
    } finally {
        clearH3dWaiter();
        setSerialOperation(null);
        if (uploadSucceeded) {
            beginScreenSnipTransitionProbe(launchAfterUpload ? 2000 : 750);
        } else {
            state.screenSnipTransitionDeadline = 0;
            setScreenSnipCapability("unavailable");
            scheduleScreenSnipProbe(6000);
        }
    }
}

function setConnectionUi(connected, detail = "") {
    const interactive = connected && state.serialOperation === null;

    els.statusDot.classList.toggle("connected", connected);
    els.connectionStatus.textContent = connected ? "Connected" : "Not connected";
    els.connectButton.textContent = connected ? "Disconnect" : "Connect";
    els.connectButton.disabled = state.serialOperation !== null;
    els.commandInput.disabled = !interactive;
    els.sendButton.disabled = !interactive;
    els.macroSendButton.disabled = !interactive;
    updateScreenSnipUi();
    document.querySelectorAll(".command-button").forEach((button) => {
        button.disabled = !interactive;
    });

    [els.baudRate, els.dataBits, els.parity, els.stopBits].forEach((control) => {
        control.disabled = connected;
    });
    els.authorizedPort.disabled = connected || state.authorizedPorts.length === 0;
    els.reconnectButton.disabled = connected || state.authorizedPorts.length === 0;

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

function portIdentity(port, index) {
    const info = port.getInfo();
    const parts = [`Authorized port ${index + 1}`];

    if (info.usbVendorId !== undefined) {
        parts.push(`VID 0x${info.usbVendorId.toString(16).padStart(4, "0")}`);
    }
    if (info.usbProductId !== undefined) {
        parts.push(`PID 0x${info.usbProductId.toString(16).padStart(4, "0")}`);
    }

    return parts.join(" | ");
}

function describePort(port) {
    const info = port.getInfo();
    const parts = [`${Number(els.baudRate.value).toLocaleString()} baud`, `${els.dataBits.value}${els.parity.value === "none" ? "N" : els.parity.value[0].toUpperCase()}${els.stopBits.value}`];
    const index = state.authorizedPorts.indexOf(port);

    if (index >= 0) {
        parts.unshift(`Authorized port ${index + 1}`);
    }
    if (info.usbVendorId !== undefined) {
        parts.push(`VID 0x${info.usbVendorId.toString(16).padStart(4, "0")}`);
    }
    if (info.usbProductId !== undefined) {
        parts.push(`PID 0x${info.usbProductId.toString(16).padStart(4, "0")}`);
    }

    return parts.join(" | ");
}

function updateAuthorizedPortDetails() {
    if (state.port) {
        return;
    }

    if (state.authorizedPorts.length === 0) {
        els.portDetails.textContent = "No authorized serial ports. Click Connect to choose one.";
        return;
    }

    const selectedIndex = Number(els.authorizedPort.value);
    const selectedPort = state.authorizedPorts[selectedIndex];
    if (!selectedPort) {
        els.portDetails.textContent = `${state.authorizedPorts.length} authorized serial ports are available.`;
        return;
    }

    const suffix = state.authorizedPorts.length === 1
        ? "Click Connect to grant/select another port."
        : "Choose a port above, then click Reconnect.";
    els.portDetails.textContent = `${portIdentity(selectedPort, selectedIndex)}. ${suffix}`;
}

async function refreshAuthorizedPorts(preferredPort = null) {
    const previousPort = state.authorizedPorts[Number(els.authorizedPort.value)] || null;
    const ports = await navigator.serial.getPorts();
    state.authorizedPorts = ports;
    els.authorizedPort.replaceChildren();

    if (ports.length === 0) {
        const option = document.createElement("option");
        option.value = "";
        option.textContent = "No authorized ports";
        els.authorizedPort.append(option);
    } else {
        ports.forEach((port, index) => {
            const option = document.createElement("option");
            option.value = String(index);
            option.textContent = portIdentity(port, index);
            els.authorizedPort.append(option);
        });

        let selectedIndex = preferredPort ? ports.indexOf(preferredPort) : -1;
        if (selectedIndex < 0 && previousPort) {
            selectedIndex = ports.indexOf(previousPort);
        }
        els.authorizedPort.value = String(selectedIndex >= 0 ? selectedIndex : 0);
    }

    els.authorizedPort.disabled = Boolean(state.port) || ports.length === 0;
    els.reconnectButton.disabled = Boolean(state.port) || ports.length === 0;
    updateAuthorizedPortDetails();
    return ports;
}

function appendSerialBytes(bytes) {
    if (bytes.byteLength === 0) {
        return;
    }
    appendTerminal(state.textDecoder.decode(bytes, { stream: true }));
}

function setScreenSnipIdle() {
    if (state.screenSnip?.timeoutId !== undefined) {
        window.clearTimeout(state.screenSnip.timeoutId);
    }
    state.screenSnip = null;
    updateScreenSnipUi();
}

function abortScreenSnip(message, flushHeader = true) {
    const capture = state.screenSnip;
    if (!capture) {
        return;
    }

    if (flushHeader && capture.phase === "header" && capture.headerBytes.length > 0) {
        appendSerialBytes(Uint8Array.from(capture.headerBytes));
    }
    setScreenSnipIdle();
    appendSystem(message);
}

function parseScreenSnipHeader(lineBytes) {
    const line = new TextDecoder("ascii").decode(lineBytes).replace(/[\r\n]+$/, "");
    const match = /^H3SNIP1 ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) IDX8 ([0-9]+) ([0-9]+)$/.exec(line);
    if (!match) {
        return null;
    }

    const values = match.slice(1).map(Number);
    const [sourceWidth, sourceHeight, displayWidth, displayHeight, paletteBytes, pixelBytes] = values;
    if (sourceWidth <= 0 || sourceHeight <= 0 || displayWidth <= 0 || displayHeight <= 0 ||
        sourceWidth * sourceHeight > SCREEN_SNIP_MAX_SOURCE_PIXELS ||
        displayWidth * displayHeight > SCREEN_SNIP_MAX_DISPLAY_PIXELS ||
        paletteBytes !== 256 || pixelBytes !== sourceWidth * sourceHeight) {
        return null;
    }

    return { sourceWidth, sourceHeight, displayWidth, displayHeight, paletteBytes, pixelBytes };
}

function rgb332ToRgb(pixel) {
    const red = (pixel >> 5) & 0x07;
    const green = (pixel >> 2) & 0x07;
    const blue = pixel & 0x03;
    return [
        (red << 5) | (red << 2) | (red >> 1),
        (green << 5) | (green << 2) | (green >> 1),
        blue * 0x55,
    ];
}

async function downloadScreenSnip(capture) {
    const palette = capture.payload.subarray(0, capture.paletteBytes);
    const pixels = capture.payload.subarray(capture.paletteBytes);
    const canvas = document.createElement("canvas");
    canvas.width = capture.displayWidth;
    canvas.height = capture.displayHeight;
    const context = canvas.getContext("2d");
    const image = context.createImageData(capture.displayWidth, capture.displayHeight);
    const rgba = image.data;

    for (let y = 0; y < capture.displayHeight; ++y) {
        const sourceY = Math.floor(y * capture.sourceHeight / capture.displayHeight);
        const sourceRow = sourceY * capture.sourceWidth;
        const outputRow = y * capture.displayWidth;

        for (let x = 0; x < capture.displayWidth; ++x) {
            const sourceX = Math.floor(x * capture.sourceWidth / capture.displayWidth);
            const paletteIndex = pixels[sourceRow + sourceX];
            const [red, green, blue] = rgb332ToRgb(palette[paletteIndex]);
            const output = (outputRow + x) * 4;
            rgba[output] = red;
            rgba[output + 1] = green;
            rgba[output + 2] = blue;
            rgba[output + 3] = 255;
        }
    }

    context.putImageData(image, 0, 0);
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
    if (!blob) {
        appendSystem("Screen snip failed: browser could not encode PNG.");
        return;
    }

    const now = new Date();
    const stamp = now.toISOString().replaceAll(":", "-").replace(".000Z", "Z");
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `hazard3-doom-hdmi-${capture.displayWidth}x${capture.displayHeight}-${stamp}.png`;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
    appendSystem(`Downloaded HDMI screen snip ${capture.displayWidth}x${capture.displayHeight} from ${capture.sourceWidth}x${capture.sourceHeight} source.`);
}

function finishScreenSnip() {
    const capture = state.screenSnip;
    if (!capture || capture.phase !== "payload" || capture.received !== capture.payload.byteLength) {
        return;
    }

    setScreenSnipIdle();
    void downloadScreenSnip(capture);
}

function processScreenSnipBytes(bytes) {
    let offset = 0;

    while (offset < bytes.byteLength && state.screenSnip) {
        const capture = state.screenSnip;
        if (capture.phase === "header") {
            const byte = bytes[offset++];

            if (byte === SCREEN_SNIP_CAPABILITY_NAK_BYTE) {
                abortScreenSnip(
                    "Screen snip unavailable: no retained HDMI frame is available.",
                    false);
                continue;
            }
            if (byte === SCREEN_SNIP_CAPABILITY_ACK_BYTE ||
                byte === SCREEN_SNIP_CAPABILITY_REQUEST_BYTE ||
                byte === SCREEN_SNIP_REQUEST_BYTE) {
                continue;
            }

            capture.headerBytes.push(byte);
            if (capture.headerBytes.length > 1024) {
                abortScreenSnip("Screen snip failed: response header was too long.");
                break;
            }
            if (byte !== 0x0a) {
                continue;
            }

            const lineBytes = Uint8Array.from(capture.headerBytes);
            capture.headerBytes = [];
            const header = parseScreenSnipHeader(lineBytes);
            if (!header) {
                const line = new TextDecoder("ascii").decode(lineBytes);
                if (line.includes("H3SNIP1")) {
                    abortScreenSnip("Screen snip failed: invalid firmware response.", false);
                    break;
                }
                appendSerialBytes(lineBytes);
                continue;
            }

            Object.assign(capture, header);
            capture.payload = new Uint8Array(header.paletteBytes + header.pixelBytes);
            capture.received = 0;
            capture.phase = "payload";
            appendSystem(`Receiving HDMI screen snip ${header.displayWidth}x${header.displayHeight} (${header.sourceWidth}x${header.sourceHeight} source)...`);
            continue;
        }

        const remaining = capture.payload.byteLength - capture.received;
        const count = Math.min(remaining, bytes.byteLength - offset);
        capture.payload.set(bytes.subarray(offset, offset + count), capture.received);
        capture.received += count;
        offset += count;

        if (capture.received === capture.payload.byteLength) {
            finishScreenSnip();
        }
    }

    if (offset < bytes.byteLength) {
        appendSerialBytes(bytes.subarray(offset));
    }
}

function processSerialBytes(bytes) {
    observeH3dResponse(bytes);

    if (state.screenSnip) {
        processScreenSnipBytes(bytes);
        return;
    }

    const output = new Uint8Array(bytes.byteLength);
    let outputLength = 0;
    let probeResponse = null;

    for (const byte of bytes) {
        if (byte === SCREEN_SNIP_CAPABILITY_ACK_BYTE ||
            byte === SCREEN_SNIP_CAPABILITY_NAK_BYTE) {
            if ((state.screenSnipProbe !== null || screenSnipTransitionActive()) &&
                probeResponse === null) {
                probeResponse = byte;
            }
            continue;
        }

        // Screen-snip protocol controls are never terminal text. Consume any
        // adapter/local echo instead of rendering an unprintable glyph.
        if (byte === SCREEN_SNIP_CAPABILITY_REQUEST_BYTE ||
            byte === SCREEN_SNIP_REQUEST_BYTE) {
            continue;
        }

        output[outputLength++] = byte;
    }

    if (outputLength !== 0) {
        appendSerialBytes(output.subarray(0, outputLength));
    }

    if (probeResponse !== null &&
        (state.screenSnipProbe !== null || screenSnipTransitionActive())) {
        const available = probeResponse === SCREEN_SNIP_CAPABILITY_ACK_BYTE;
        const previousCapability = state.screenSnipCapability;

        state.screenSnipCapabilityProtocolKnown = true;
        state.screenSnipTransitionDeadline = 0;
        clearScreenSnipProbe(available);
        setScreenSnipCapability(available ? "available" : "unavailable");
        startScreenSnipCapabilityWatch();

        if (!available && previousCapability !== "unavailable") {
            appendSystem(
                "Screen snip unavailable: no capturable HDMI frame has been presented yet.");
        }
    }
}

async function readLoop() {
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
                    processSerialBytes(value);
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

        const tail = state.textDecoder.decode();
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
    state.textDecoder = new TextDecoder();
    state.screenSnipCapabilityProtocolKnown = false;
    state.screenSnipTransitionDeadline = 0;
    stopScreenSnipCapabilityWatch();
    els.rxCount.textContent = "0";
    els.txCount.textContent = "0";
    setScreenSnipCapability("checking");
    setConnectionUi(true, describePort(port));
    startSessionTimer();
    saveSettings();
    appendSystem(`Connected: ${describePort(port)}`);
    state.readLoopPromise = readLoop();
    void probeScreenSnipCapability();
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
        await refreshAuthorizedPorts(port);
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
        const ports = await refreshAuthorizedPorts();
        if (ports.length === 0) {
            appendSystem("No previously authorized serial port is available. Use Connect first.");
            return;
        }

        const selectedIndex = Number(els.authorizedPort.value);
        const port = ports[selectedIndex];
        if (!port) {
            appendSystem("Select an authorized serial port first.");
            return;
        }
        await openPort(port);
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
    cancelScheduledScreenSnipProbe();
    stopScreenSnipCapabilityWatch();
    clearScreenSnipProbe();
    clearH3dWaiter(new Error("serial connection closed"));
    state.serialOperation = null;
    state.screenSnipCapabilityProtocolKnown = false;
    setScreenSnipCapability("unavailable");
    if (state.screenSnip) {
        abortScreenSnip("Screen snip cancelled: disconnected.", false);
    }

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
    if (!sent) {
        return;
    }

    const trimmed = command.trim();
    if (/^(?:i2c\s+gui|sao\s+gui|j|b)$/i.test(trimmed)) {
        beginScreenSnipTransitionProbe(trimmed.length === 1 ? 2000 : 1000);
    }
    if (!trimmed) {
        return;
    }
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

function copyTerminalFallback(text) {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();

    const copied = document.execCommand("copy");
    textarea.remove();
    if (!copied) {
        throw new Error("browser clipboard command was rejected");
    }
}

async function copyTerminalContents() {
    const text = els.terminal.textContent;

    try {
        if (navigator.clipboard?.writeText && window.isSecureContext) {
            await navigator.clipboard.writeText(text);
        } else {
            copyTerminalFallback(text);
        }

        const originalLabel = els.copyButtonLabel.textContent;
        els.copyButtonLabel.textContent = "Copied";
        els.copyButton.classList.add("copy-success");
        window.setTimeout(() => {
            els.copyButtonLabel.textContent = originalLabel;
            els.copyButton.classList.remove("copy-success");
        }, 1200);
    } catch (error) {
        appendSystem(`Copy failed: ${error.message}`);
    }
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

async function requestScreenSnip() {
    if (!state.port?.writable) {
        appendSystem("Not connected.");
        return;
    }
    if (state.screenSnip) {
        appendSystem("A screen snip is already in progress.");
        return;
    }
    if (!await probeScreenSnipCapability()) {
        appendSystem(screenSnipStatusText());
        return;
    }

    cancelScheduledScreenSnipProbe();
    state.screenSnip = {
        phase: "header",
        headerBytes: [],
        payload: null,
        received: 0,
        timeoutId: window.setTimeout(() => {
            abortScreenSnip("Screen snip timed out: the active firmware did not return a capture frame.");
        }, SCREEN_SNIP_TIMEOUT_MS),
    };
    updateScreenSnipUi();
    appendSystem("Requesting full-resolution HDMI screen snip...");

    const sent = await writeBytes(new Uint8Array([SCREEN_SNIP_REQUEST_BYTE]));
    if (!sent && state.screenSnip) {
        abortScreenSnip("Screen snip request could not be sent.", false);
    }
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
    els.authorizedPort.addEventListener("change", updateAuthorizedPortDetails);
    els.clearButton.addEventListener("click", clearTerminal);
    els.downloadButton.addEventListener("click", downloadLog);
    els.copyButton.addEventListener("click", copyTerminalContents);
    els.screenSnipButton.addEventListener("click", requestScreenSnip);
    els.h3dFileInput.addEventListener("change", selectH3dFile);
    els.h3dUploadButton.addEventListener("click", uploadH3dImage);

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
        button.addEventListener("click", async () => {
            const value = button.dataset.raw;
            const sent = await writeBytes(new TextEncoder().encode(value), els.localEcho.checked ? value : "");
            if (sent && value === "Q") {
                beginScreenSnipTransitionProbe(750);
            }
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
                    if (await writeBytes(new Uint8Array([0x18]), els.localEcho.checked ? "^X" : "")) {
                        beginScreenSnipTransitionProbe(750);
                    }
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
        navigator.serial.addEventListener("connect", () => {
            void refreshAuthorizedPorts();
        });
        navigator.serial.addEventListener("disconnect", async (event) => {
            const disconnectedPort = event.port || event.target;
            if (disconnectedPort === state.port) {
                appendSystem("Device disconnected by the operating system.");
                await disconnect();
            }
            await refreshAuthorizedPorts();
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
        await refreshAuthorizedPorts();
    } catch (error) {
        appendSystem(`Could not enumerate authorized ports: ${error.message}`);
    }
}

initialize();
