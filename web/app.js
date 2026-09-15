"use strict";

const MAX_TERMINAL_CHARS = 1_000_000;
const TERMINAL_MIN_HEIGHT_PX = 112;
const TERMINAL_MAX_AUTO_HEIGHT_PX = 736;
const TERMINAL_MAX_MANUAL_HEIGHT_PX = 1200;
const TERMINAL_VIEWPORT_MARGIN_PX = 16;
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
const WAD_PACKAGE_MAGIC = 0x31573348;
const WAD_HEADER_BYTES = 64;
const WAD_FORMAT_VERSION = 1;
const WAD_FLAG_CRC32 = 1;
const WAD_UPLOAD_CHUNK_BYTES = 4096;
const WAD_READY_MARKER = "H3W READY\r\n";
const WAD_DATA_MARKER = "H3W DATA\r\n";
const WAD_OK_MARKER = "H3W OK";
const WAD_ERROR_MARKER = "H3W ERROR";
const WAD_RESPONSE_TIMEOUT_MS = 10_000;
const WAD_RESULT_MARGIN_MS = 20_000;
const WAD_MEMORY_PROFILES = {
    "64m": { base: 0x22c00000, limit: 0x23c00000 },
    "32m": { base: 0x21000000, limit: 0x21c00000 },
};
const CONSOLE_FIRMWARE_MAX_BYTES = 16 * 1024 * 1024;
const CONSOLE_FIRMWARE_LOOPBACK_ORIGIN = "http://127.0.0.1:8000";
const CONSOLE_FIRMWARE_STATUS_TIMEOUT_MS = 8000;
const CONSOLE_FIRMWARE_HEALTH_TIMEOUT_MS = 2000;
const CONSOLE_FIRMWARE_HEALTH_INTERVAL_MS = 5000;
const DEVICE_TOOL_CHANNEL_NAME = "hazard3-doom-device-tool";
const DEVICE_TOOL_HEARTBEAT_INTERVAL_MS = 10_000;
const DEVICE_TOOL_STALE_AFTER_MS = 30_000;
const UART_LOCK_NAME = "hazard3-doom-uart";
const PAGE_INSTANCE_ID = typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;

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
    wadBytes: null,
    wadCrc32: null,
    wadImage: null,
    serialResponseWaiter: null,
    consoleFirmware: null,
    consoleFirmwareLoaderAvailable: false,
    consoleFirmwareOpenOcdKnown: false,
    consoleFirmwareOpenOcdReady: false,
    consoleFirmwareAccessKey: "",
    consoleFirmwareBusy: false,
    consoleFirmwareCheckSequence: 0,
    consoleFirmwareHealthTimer: null,
    serialOperation: null,
    uartConnecting: false,
    uartConnectionIssue: null,
    uartLockHeld: false,
    uartLockRelease: null,
    uartLockRequest: null,
    deviceToolChannel: null,
    deviceToolHeartbeatTimer: null,
    otherDeviceToolPages: new Map(),
    otherUartOwners: new Set(),
    textDecoder: new TextDecoder(),
    terminalHeightOffset: 0,
    terminalResizeFrame: null,
    terminalLayoutObserver: null,
};

const els = {
    appVersion: document.getElementById("appVersion"),
    statusDot: document.getElementById("statusDot"),
    connectionStatus: document.getElementById("connectionStatus"),
    portDetails: document.getElementById("portDetails"),
    unsupportedNotice: document.getElementById("unsupportedNotice"),
    connectButton: document.getElementById("connectButton"),
    reconnectButton: document.getElementById("reconnectButton"),
    serialPanelStatus: document.getElementById("serialPanelStatus"),
    authorizedPort: document.getElementById("authorizedPort"),
    baudRate: document.getElementById("baudRate"),
    dataBits: document.getElementById("dataBits"),
    parity: document.getElementById("parity"),
    stopBits: document.getElementById("stopBits"),
    lineEnding: document.getElementById("lineEnding"),
    autoScroll: document.getElementById("autoScroll"),
    localEcho: document.getElementById("localEcho"),
    terminalPanel: document.querySelector(".terminal-panel"),
    terminal: document.getElementById("terminal"),
    terminalResizeHandle: document.getElementById("terminalResizeHandle"),
    controlsPanel: document.querySelector(".controls-panel"),
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
    h3dUploadDiagnostic: document.getElementById("h3dUploadDiagnostic"),
    h3dUartRequirement: document.getElementById("h3dUartRequirement"),
    h3dUartRequirementTitle: document.getElementById("h3dUartRequirementTitle"),
    h3dUartRequirementDetail: document.getElementById("h3dUartRequirementDetail"),
    h3dConnectUartButton: document.getElementById("h3dConnectUartButton"),
    wadFileInput: document.getElementById("wadFileInput"),
    wadFileName: document.getElementById("wadFileName"),
    wadFileDetails: document.getElementById("wadFileDetails"),
    wadVisibleName: document.getElementById("wadVisibleName"),
    wadMemoryProfile: document.getElementById("wadMemoryProfile"),
    wadUploadButton: document.getElementById("wadUploadButton"),
    wadLaunchAfterUpload: document.getElementById("wadLaunchAfterUpload"),
    wadProgress: document.getElementById("wadProgress"),
    wadProgressLabel: document.getElementById("wadProgressLabel"),
    wadUploadDiagnostic: document.getElementById("wadUploadDiagnostic"),
    wadUartRequirement: document.getElementById("wadUartRequirement"),
    wadUartRequirementTitle: document.getElementById("wadUartRequirementTitle"),
    wadUartRequirementDetail: document.getElementById("wadUartRequirementDetail"),
    wadConnectUartButton: document.getElementById("wadConnectUartButton"),
    firmwareLoaderStatus: document.getElementById("firmwareLoaderStatus"),
    firmwareOpenOcdStatus: document.getElementById("firmwareOpenOcdStatus"),
    firmwareLoaderRefreshButton: document.getElementById("firmwareLoaderRefreshButton"),
    firmwareLoaderAccessKey: document.getElementById("firmwareLoaderAccessKey"),
    firmwareFileInput: document.getElementById("firmwareFileInput"),
    firmwareFileName: document.getElementById("firmwareFileName"),
    firmwareFileDetails: document.getElementById("firmwareFileDetails"),
    firmwareUploadButton: document.getElementById("firmwareUploadButton"),
    firmwareProgress: document.getElementById("firmwareProgress"),
    firmwareProgressLabel: document.getElementById("firmwareProgressLabel"),
    firmwareLog: document.getElementById("firmwareLog"),
    clearButton: document.getElementById("clearButton"),
    rxCount: document.getElementById("rxCount"),
    txCount: document.getElementById("txCount"),
    sessionTime: document.getElementById("sessionTime"),
    macroInput: document.getElementById("macroInput"),
    macroSendButton: document.getElementById("macroSendButton"),
};

const serialSupported = "serial" in navigator;

function updateAppVersion() {
    const versionInfo = window.HAZARD3_DOOM_VERSION;

    if (!els.appVersion || !versionInfo || !versionInfo.display) {
        return;
    }

    els.appVersion.textContent = versionInfo.display;
    els.appVersion.title = `Hazard3-Doom project version ${versionInfo.display}`;
}

function setButtonDisabledReason(button, reason = "") {
    if (!button) {
        return;
    }
    if (button.disabled && reason) {
        button.title = reason;
    } else if (button.dataset.enabledTitle) {
        button.title = button.dataset.enabledTitle;
    } else {
        button.removeAttribute("title");
    }
}

function serialOperationDisabledReason() {
    if (state.consoleFirmwareBusy) {
        return "Wait for console firmware loading to finish.";
    }
    if (state.screenSnip !== null) {
        return "Wait for the screen capture to finish.";
    }
    if (state.serialOperation === "h3d-upload") {
        return "Wait for the H3D upload to finish.";
    }
    if (state.serialOperation === "wad-upload") {
        return "Wait for the IWAD upload to finish.";
    }
    if (state.serialOperation !== null) {
        return "Wait for the current UART operation to finish.";
    }
    return "";
}

class UartOwnershipError extends Error {
    constructor(message) {
        super(message);
        this.name = "UartOwnershipError";
    }
}

function otherDeviceToolPageCount() {
    return state.otherDeviceToolPages.size;
}

function anotherDeviceToolOwnsUart() {
    return state.otherUartOwners.size !== 0;
}

function updateDeviceToolPeerUi() {
    if (!state.port) {
        updateAuthorizedPortDetails();
    }
    updateH3dUploaderUi();
    updateWadUploaderUi();
}

function broadcastDeviceToolState(type = "presence") {
    if (!state.deviceToolChannel) {
        return;
    }

    state.deviceToolChannel.postMessage({
        type,
        instanceId: PAGE_INSTANCE_ID,
        uartOwned: Boolean(state.port),
        timestamp: Date.now(),
    });
}

function rememberDeviceToolPeer(message) {
    const instanceId = message?.instanceId;
    if (typeof instanceId !== "string" || instanceId === PAGE_INSTANCE_ID) {
        return;
    }

    state.otherDeviceToolPages.set(instanceId, Date.now());
    if (message.uartOwned) {
        state.otherUartOwners.add(instanceId);
    } else {
        state.otherUartOwners.delete(instanceId);
    }
    if (!anotherDeviceToolOwnsUart() &&
        state.uartConnectionIssue?.kind === "ownership") {
        clearUartConnectionIssue();
    }
    updateDeviceToolPeerUi();
}

function forgetDeviceToolPeer(instanceId) {
    if (typeof instanceId !== "string") {
        return;
    }

    state.otherDeviceToolPages.delete(instanceId);
    state.otherUartOwners.delete(instanceId);
    if (!anotherDeviceToolOwnsUart() &&
        state.uartConnectionIssue?.kind === "ownership") {
        clearUartConnectionIssue();
    }
    updateDeviceToolPeerUi();
}

function pruneDeviceToolPeers() {
    const staleBefore = Date.now() - DEVICE_TOOL_STALE_AFTER_MS;
    let changed = false;

    for (const [instanceId, lastSeen] of state.otherDeviceToolPages) {
        if (lastSeen >= staleBefore) {
            continue;
        }
        state.otherDeviceToolPages.delete(instanceId);
        state.otherUartOwners.delete(instanceId);
        changed = true;
    }

    if (changed) {
        if (!anotherDeviceToolOwnsUart() &&
            state.uartConnectionIssue?.kind === "ownership") {
            clearUartConnectionIssue();
        }
        updateDeviceToolPeerUi();
    }
}

function startDeviceToolCoordination() {
    if (!("BroadcastChannel" in window)) {
        return;
    }

    const channel = new BroadcastChannel(DEVICE_TOOL_CHANNEL_NAME);
    state.deviceToolChannel = channel;
    channel.addEventListener("message", (event) => {
        const message = event.data;
        if (!message || message.instanceId === PAGE_INSTANCE_ID) {
            return;
        }

        if (message.type === "goodbye") {
            forgetDeviceToolPeer(message.instanceId);
            return;
        }

        if (message.type === "hello" || message.type === "presence" ||
            message.type === "uart-owner") {
            rememberDeviceToolPeer(message);
            if (message.type === "hello") {
                broadcastDeviceToolState("presence");
            }
        }
    });

    broadcastDeviceToolState("hello");
    state.deviceToolHeartbeatTimer = window.setInterval(() => {
        pruneDeviceToolPeers();
        broadcastDeviceToolState("presence");
    }, DEVICE_TOOL_HEARTBEAT_INTERVAL_MS);
}

function webLocksSupported() {
    return "locks" in navigator && typeof navigator.locks.request === "function";
}

async function acquireUartLock() {
    if (!webLocksSupported()) {
        return true;
    }

    if (state.uartLockRequest !== null) {
        try {
            await state.uartLockRequest;
        } catch {
            // A failed Web Lock request falls back to the serial port's own exclusivity.
        }
    }

    let resolveAcquired;
    let settled = false;
    const acquired = new Promise((resolve) => {
        resolveAcquired = resolve;
    });

    try {
        const request = navigator.locks.request(
            UART_LOCK_NAME,
            { mode: "exclusive", ifAvailable: true },
            async (lock) => {
                if (!lock) {
                    settled = true;
                    resolveAcquired(false);
                    return;
                }

                let releaseLock;
                const holdLock = new Promise((resolve) => {
                    releaseLock = resolve;
                });
                state.uartLockHeld = true;
                state.uartLockRelease = releaseLock;
                settled = true;
                resolveAcquired(true);
                await holdLock;
                state.uartLockHeld = false;
                state.uartLockRelease = null;
            },
        );
        state.uartLockRequest = request;
        void request.catch((error) => {
            if (!settled) {
                settled = true;
                resolveAcquired(true);
                appendSystem(`UART tab-lock warning: ${error.message}`);
            }
        }).finally(() => {
            if (state.uartLockRequest === request) {
                state.uartLockRequest = null;
            }
        });
    } catch (error) {
        appendSystem(`UART tab-lock warning: ${error.message}`);
        return true;
    }

    return acquired;
}

function releaseUartLock() {
    const releaseLock = state.uartLockRelease;
    if (releaseLock) {
        state.uartLockRelease = null;
        releaseLock();
    }
}

function clearUartConnectionIssue() {
    state.uartConnectionIssue = null;
}

function setUartConnectionIssue(error) {
    if (error?.name === "UartOwnershipError") {
        state.uartConnectionIssue = {
            kind: "ownership",
            title: "UART already in use",
            detail: "Another Hazard3-Doom Device Tool page from this site owns the UART. Disconnect it there, then retry.",
        };
        return;
    }

    const browserDetail = error?.message ? ` Browser: ${error.message}` : "";
    state.uartConnectionIssue = {
        kind: "open",
        title: "UART connection failed",
        detail: "The selected serial port could not be opened. It may already be in use by another Device Tool page, PuTTY, or another serial application." + browserDetail,
    };
}

function screenSnipStatusText() {
    if (!state.port) {
        return "Screen snip unavailable: connect to the board first.";
    }
    if (state.screenSnip !== null) {
        return "Screen snip capture is in progress.";
    }
    if (state.consoleFirmwareBusy) {
        return "Screen snip is paused while console firmware is loading.";
    }
    if (state.serialOperation === "h3d-upload") {
        return "Screen snip is paused while an H3D image is uploading.";
    }
    if (state.serialOperation === "wad-upload") {
        return "Screen snip is paused while an IWAD is uploading.";
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
        !state.consoleFirmwareBusy &&
        state.screenSnipCapability === "available" &&
        state.screenSnip === null;
    const status = screenSnipStatusText();

    els.screenSnipButton.disabled = !available;
    els.screenSnipButton.textContent = state.screenSnip !== null ? "Capturing..." : "Screen snip";
    els.screenSnipControl.title = status;
    els.screenSnipButton.title = status;
    els.screenSnipButton.setAttribute("aria-label", status);
    updateConsoleFirmwareUi();
    updateH3dUploaderUi();
    updateWadUploaderUi();
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

const CRC32_TABLE = (() => {
    const table = new Uint32Array(256);
    for (let value = 0; value < table.length; ++value) {
        let crc = value;
        for (let bit = 0; bit < 8; ++bit) {
            crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
        }
        table[value] = crc >>> 0;
    }
    return table;
})();

function crc32(bytes) {
    let crc = 0xffffffff;
    for (const byte of bytes) {
        crc = (crc >>> 8) ^ CRC32_TABLE[(crc ^ byte) & 0xff];
    }
    return (crc ^ 0xffffffff) >>> 0;
}

function validateConsoleFirmware(bytes) {
    if (bytes.byteLength < 52) {
        throw new Error("file is shorter than a 32-bit ELF header");
    }
    if (bytes[0] !== 0x7f || bytes[1] !== 0x45 || bytes[2] !== 0x4c || bytes[3] !== 0x46) {
        throw new Error("invalid ELF magic");
    }
    if (bytes[4] !== 1 || bytes[5] !== 1 || bytes[6] !== 1) {
        throw new Error("expected a 32-bit little-endian ELF version 1");
    }
    if (bytes.byteLength > CONSOLE_FIRMWARE_MAX_BYTES) {
        throw new Error("ELF exceeds the 16 MiB browser safety limit");
    }

    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    if (view.getUint16(16, true) !== 2) {
        throw new Error("expected an executable ELF");
    }
    if (view.getUint16(18, true) !== 243) {
        throw new Error("ELF machine is not RISC-V");
    }
    if (view.getUint32(20, true) !== 1) {
        throw new Error("unsupported ELF version");
    }

    return {
        bytes,
        entryAddress: view.getUint32(24, true),
    };
}

function updateConsoleFirmwareUi() {
    const blocked = state.consoleFirmwareBusy ||
        state.serialOperation !== null || state.screenSnip !== null;
    const ready = state.consoleFirmwareLoaderAvailable &&
        state.consoleFirmwareOpenOcdReady &&
        state.consoleFirmware !== null && !blocked;

    els.firmwareFileInput.disabled = blocked;
    els.firmwareUploadButton.disabled = !ready;
    let disabledReason = "";
    if (state.consoleFirmwareBusy) {
        els.firmwareUploadButton.textContent = "Loading...";
        disabledReason = "Console firmware loading is already in progress.";
    } else if (!state.consoleFirmwareLoaderAvailable) {
        els.firmwareUploadButton.textContent = "Load console firmware";
        disabledReason = "Start the local web-server.py helper and refresh its status first.";
    } else if (!state.consoleFirmwareOpenOcdKnown) {
        els.firmwareUploadButton.textContent = "Load console firmware";
        disabledReason = "Refresh the local helper status before loading console firmware.";
    } else if (!state.consoleFirmwareOpenOcdReady) {
        els.firmwareUploadButton.textContent = "Start OpenOCD first";
        disabledReason = "Start OpenOCD so its GDB server is listening on port 3333.";
    } else if (state.consoleFirmware === null) {
        els.firmwareUploadButton.textContent = "Load console firmware";
        disabledReason = "Select a 32-bit RISC-V ELF console firmware file first.";
    } else if (blocked) {
        els.firmwareUploadButton.textContent = "Load console firmware";
        disabledReason = serialOperationDisabledReason();
    } else {
        els.firmwareUploadButton.textContent = "Load console firmware";
    }
    setButtonDisabledReason(els.firmwareUploadButton, disabledReason);
}

function updateConsoleFirmwareOpenOcdStatus() {
    els.firmwareOpenOcdStatus.classList.remove("ok", "error");
    if (!state.consoleFirmwareLoaderAvailable) {
        els.firmwareOpenOcdStatus.textContent = "Unknown - local helper unavailable";
        return;
    }
    if (!state.consoleFirmwareOpenOcdKnown) {
        els.firmwareOpenOcdStatus.textContent = "Unknown - refresh local helper";
        return;
    }
    if (state.consoleFirmwareOpenOcdReady) {
        els.firmwareOpenOcdStatus.textContent = "Ready - GDB server on port 3333";
        els.firmwareOpenOcdStatus.classList.add("ok");
    } else {
        els.firmwareOpenOcdStatus.textContent = "Not detected on port 3333 - start OpenOCD";
        els.firmwareOpenOcdStatus.classList.add("error");
    }
}

function clearUploadDiagnostic(element) {
    element.hidden = true;
    element.textContent = "";
}

function showMonitorUploadDiagnostic(element, protocol) {
    let message = `${protocol} did not receive READY from the resident monitor. ` +
        "Confirm that the Hazard3 boot monitor is running and waiting at the > prompt. ";

    if (state.consoleFirmwareLoaderAvailable && state.consoleFirmwareOpenOcdKnown) {
        if (state.consoleFirmwareOpenOcdReady) {
            message += "OpenOCD is detected on 127.0.0.1:3333. If the monitor is not running, " +
                "use the Console firmware uploader above to load or reload hazard3-boot-monitor.elf, " +
                "then retry from the > prompt.";
        } else {
            message += "OpenOCD is not detected on 127.0.0.1:3333. If the console firmware has not " +
                "already been loaded, start OpenOCD with the matching board configuration, use the " +
                "Console firmware uploader above to load hazard3-boot-monitor.elf, then retry. " +
                "OpenOCD does not need to remain running after the monitor has been loaded.";
        }
    } else {
        message += "If the monitor has not already been loaded, start web-server.py and OpenOCD, " +
            "then use the Console firmware uploader above to load hazard3-boot-monitor.elf.";
    }

    element.textContent = message;
    element.hidden = false;
}

function appendFirmwareLog(text) {
    if (!text) {
        return;
    }
    els.firmwareLog.textContent += text.endsWith("\n") ? text : `${text}\n`;
    els.firmwareLog.scrollTop = els.firmwareLog.scrollHeight;
}

function isLoopbackHostname(hostname) {
    return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "[::1]";
}

function consoleFirmwareHelperOrigin() {
    return isLoopbackHostname(window.location.hostname)
        ? window.location.origin
        : CONSOLE_FIRMWARE_LOOPBACK_ORIGIN;
}

async function fetchConsoleFirmwareHelper(path, options = {}) {
    const headers = new Headers(options.headers || {});
    if (state.consoleFirmwareAccessKey) {
        headers.set("X-Hazard3-Doom-Key", state.consoleFirmwareAccessKey);
    }

    const requestOptions = {
        ...options,
        headers,
        cache: options.cache || "no-store",
    };
    if (!isLoopbackHostname(window.location.hostname)) {
        requestOptions.targetAddressSpace = "loopback";
    }

    return fetch(`${consoleFirmwareHelperOrigin()}${path}`, requestOptions);
}

function cancelConsoleFirmwareHealthCheck() {
    if (state.consoleFirmwareHealthTimer !== null) {
        clearTimeout(state.consoleFirmwareHealthTimer);
        state.consoleFirmwareHealthTimer = null;
    }
}

function scheduleConsoleFirmwareHealthCheck() {
    cancelConsoleFirmwareHealthCheck();
    if (!state.consoleFirmwareLoaderAvailable) {
        return;
    }
    state.consoleFirmwareHealthTimer = setTimeout(() => {
        state.consoleFirmwareHealthTimer = null;
        void checkConsoleFirmwareLoader({ background: true });
    }, CONSOLE_FIRMWARE_HEALTH_INTERVAL_MS);
}

function consoleFirmwareStatusChallenge() {
    if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
        return crypto.randomUUID();
    }
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

async function checkConsoleFirmwareLoader({ background = false } = {}) {
    const checkSequence = ++state.consoleFirmwareCheckSequence;
    const challenge = consoleFirmwareStatusChallenge();
    const controller = new AbortController();
    const timeoutMs = background
        ? CONSOLE_FIRMWARE_HEALTH_TIMEOUT_MS
        : CONSOLE_FIRMWARE_STATUS_TIMEOUT_MS;
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    state.consoleFirmwareAccessKey = els.firmwareLoaderAccessKey.value;
    cancelConsoleFirmwareHealthCheck();
    if (!background) {
        els.firmwareLoaderRefreshButton.disabled = true;
        els.firmwareLoaderStatus.textContent = "Checking...";
        els.firmwareLoaderStatus.classList.remove("ok", "error");
        state.consoleFirmwareLoaderAvailable = false;
        state.consoleFirmwareOpenOcdKnown = false;
        state.consoleFirmwareOpenOcdReady = false;
        updateConsoleFirmwareOpenOcdStatus();
        updateConsoleFirmwareUi();
    }

    try {
        const response = await fetchConsoleFirmwareHelper(
            `/api/console-firmware/status?challenge=${encodeURIComponent(challenge)}`,
            { method: "GET", signal: controller.signal },
        );
        let status = {};
        try {
            status = await response.json();
        } catch {
            // Keep the HTTP status as the useful diagnostic below.
        }

        if (checkSequence !== state.consoleFirmwareCheckSequence) {
            return;
        }

        state.consoleFirmwareLoaderAvailable = false;
        if (response.status === 401 && status.authentication_required === true) {
            els.firmwareLoaderStatus.textContent = state.consoleFirmwareAccessKey
                ? "Access key rejected"
                : "Access key required";
            els.firmwareProgressLabel.textContent = "Enter the local-loader access key and refresh";
        } else if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        } else if (status.challenge !== challenge) {
            throw new Error("Stale local-loader status response");
        } else {
            state.consoleFirmwareLoaderAvailable = status.available === true;
            state.consoleFirmwareOpenOcdKnown = typeof status.openocd_gdb_ready === "boolean";
            state.consoleFirmwareOpenOcdReady = status.openocd_gdb_ready === true;
            els.firmwareLoaderStatus.textContent = state.consoleFirmwareLoaderAvailable
                ? "Ready"
                : "Helper ready - loader script unavailable";
            if (!state.consoleFirmwareLoaderAvailable) {
                els.firmwareProgressLabel.textContent =
                    "Local helper found, but the firmware loader script is unavailable";
            } else if (state.consoleFirmwareOpenOcdKnown && !state.consoleFirmwareOpenOcdReady) {
                els.firmwareProgressLabel.textContent =
                    "OpenOCD not detected on 127.0.0.1:3333; start OpenOCD before loading the ELF";
            } else {
                els.firmwareProgressLabel.textContent = "Idle";
            }
        }
    } catch {
        if (checkSequence !== state.consoleFirmwareCheckSequence) {
            return;
        }
        state.consoleFirmwareLoaderAvailable = false;
        state.consoleFirmwareOpenOcdKnown = false;
        state.consoleFirmwareOpenOcdReady = false;
        els.firmwareLoaderStatus.textContent = "Unavailable - start web-server.py";
        els.firmwareProgressLabel.textContent =
            "Local helper unavailable; start web-server.py or allow browser loopback access";
    } finally {
        clearTimeout(timeout);
        if (checkSequence === state.consoleFirmwareCheckSequence) {
            els.firmwareLoaderStatus.classList.toggle("ok", state.consoleFirmwareLoaderAvailable);
            els.firmwareLoaderStatus.classList.toggle("error", !state.consoleFirmwareLoaderAvailable);
            els.firmwareLoaderRefreshButton.disabled = false;
            updateConsoleFirmwareOpenOcdStatus();
            updateConsoleFirmwareUi();
            scheduleConsoleFirmwareHealthCheck();
        }
    }
}

function updateConsoleFirmwareAccessKey() {
    cancelConsoleFirmwareHealthCheck();
    state.consoleFirmwareCheckSequence += 1;
    state.consoleFirmwareAccessKey = els.firmwareLoaderAccessKey.value;
    state.consoleFirmwareLoaderAvailable = false;
    state.consoleFirmwareOpenOcdKnown = false;
    state.consoleFirmwareOpenOcdReady = false;
    els.firmwareLoaderStatus.textContent = "Key changed - refresh";
    els.firmwareLoaderStatus.classList.remove("ok");
    els.firmwareLoaderStatus.classList.add("error");
    els.firmwareProgressLabel.textContent = "Refresh the local-loader check";
    updateConsoleFirmwareOpenOcdStatus();
    updateConsoleFirmwareUi();
}

async function selectConsoleFirmwareFile() {
    state.consoleFirmware = null;
    els.firmwareFileName.textContent = "No console firmware selected";
    els.firmwareFileDetails.textContent = "";
    els.firmwareProgress.value = 0;
    els.firmwareProgressLabel.textContent = state.consoleFirmwareLoaderAvailable
        ? "Idle"
        : "Local firmware loader unavailable";
    els.firmwareLog.textContent = "";

    const file = els.firmwareFileInput.files?.[0];
    if (!file) {
        updateConsoleFirmwareUi();
        return;
    }

    els.firmwareFileName.textContent = file.name;
    els.firmwareFileDetails.textContent = "Validating RISC-V ELF...";
    try {
        const firmware = validateConsoleFirmware(new Uint8Array(await file.arrayBuffer()));
        state.consoleFirmware = { ...firmware, fileName: file.name };
        els.firmwareFileDetails.textContent =
            `${firmware.bytes.byteLength.toLocaleString()} bytes | ` +
            `RISC-V ELF32 | entry ${formatHex32(firmware.entryAddress)}`;
    } catch (error) {
        els.firmwareFileDetails.textContent = `Invalid console firmware: ${error.message}`;
    }

    updateConsoleFirmwareUi();
}

async function loadConsoleFirmware() {
    const firmware = state.consoleFirmware;
    if (!state.consoleFirmwareLoaderAvailable || !state.consoleFirmwareOpenOcdReady || !firmware ||
        state.consoleFirmwareBusy || state.serialOperation !== null || state.screenSnip !== null) {
        return;
    }

    state.consoleFirmwareBusy = true;
    els.firmwareLog.textContent = "";
    els.firmwareProgress.value = 25;
    els.firmwareProgressLabel.textContent = "Sending ELF to local GDB loader...";
    appendFirmwareLog(`Loading ${firmware.fileName} (${firmware.bytes.byteLength.toLocaleString()} bytes).`);
    setConnectionUi(Boolean(state.port), state.port ? describePort(state.port) : "");

    try {
        const response = await fetchConsoleFirmwareHelper(
            "/api/console-firmware/load",
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/octet-stream",
                    "X-Hazard3-Doom-Local": "1",
                },
                body: firmware.bytes,
            },
        );
        const result = await response.json();
        appendFirmwareLog(result.output || "");
        if (!response.ok || result.ok !== true) {
            throw new Error(result.error || `local loader returned HTTP ${response.status}`);
        }

        els.firmwareProgress.value = 100;
        els.firmwareProgressLabel.textContent = "Console firmware loaded and resumed";
        appendFirmwareLog("Console firmware load completed successfully.");
        if (state.port) {
            beginScreenSnipTransitionProbe(1000);
        }
    } catch (error) {
        els.firmwareProgress.value = 0;
        els.firmwareProgressLabel.textContent = `Failed: ${error.message}`;
        appendFirmwareLog(`ERROR: ${error.message}`);
    } finally {
        state.consoleFirmwareBusy = false;
        setConnectionUi(Boolean(state.port), state.port ? describePort(state.port) : "");
    }
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

function updateUploaderUartRequirement(container, title, detail, button, protocol) {
    const connected = Boolean(state.port);
    const busy = state.serialOperation !== null || state.consoleFirmwareBusy;
    const anotherOwner = anotherDeviceToolOwnsUart();
    const issue = state.uartConnectionIssue;

    container.classList.toggle("connected", connected);
    container.classList.toggle("unavailable", !serialSupported);
    container.classList.toggle("connecting", !connected && state.uartConnecting);
    container.classList.toggle("error", !connected && !state.uartConnecting &&
        (Boolean(issue) || anotherOwner));

    if (!serialSupported) {
        title.textContent = "Web Serial unavailable";
        detail.textContent = "Use a current Chromium-based browser to connect the UART.";
        button.textContent = "UART unavailable";
        button.disabled = true;
        setButtonDisabledReason(button, "Web Serial is not available in this browser.");
        return;
    }

    if (connected) {
        title.textContent = "UART connected";
        detail.textContent = `${protocol} can use the active Web Serial connection.`;
        button.textContent = "Connected";
        button.disabled = true;
        setButtonDisabledReason(button, "UART is already connected.");
        return;
    }

    if (state.uartConnecting) {
        title.textContent = "Connecting UART";
        detail.textContent = "Complete the browser serial-port chooser and wait for the port to open.";
        button.textContent = "Connecting...";
        button.disabled = true;
        setButtonDisabledReason(button, "A UART connection is already in progress.");
        return;
    }

    if (issue) {
        title.textContent = issue.title;
        detail.textContent = issue.detail;
        button.textContent = "Retry UART";
        button.disabled = busy;
        setButtonDisabledReason(button, serialOperationDisabledReason());
        return;
    }

    if (anotherOwner) {
        title.textContent = "UART already in use";
        detail.textContent = "Another Device Tool page from this site reports that it owns the UART. Disconnect it there, then retry.";
        button.textContent = "Retry UART";
        button.disabled = busy;
        setButtonDisabledReason(button, serialOperationDisabledReason());
        return;
    }

    title.textContent = "UART connection required";
    detail.textContent = `Connect Web Serial before starting the ${protocol} upload.`;
    if (otherDeviceToolPageCount() !== 0) {
        detail.textContent += " Another Device Tool page is also open; only one page can own the UART.";
    }
    button.textContent = "Connect UART";
    button.disabled = busy;
    setButtonDisabledReason(button, serialOperationDisabledReason());
}

function updateH3dUploaderUi() {
    const uploading = state.serialOperation === "h3d-upload";
    const ready = Boolean(state.port && state.h3dImage &&
        state.serialOperation === null && state.screenSnip === null &&
        !state.consoleFirmwareBusy);

    updateUploaderUartRequirement(
        els.h3dUartRequirement,
        els.h3dUartRequirementTitle,
        els.h3dUartRequirementDetail,
        els.h3dConnectUartButton,
        "H3L",
    );

    els.h3dFileInput.disabled = uploading || state.consoleFirmwareBusy;
    els.h3dLaunchAfterUpload.disabled = uploading || state.consoleFirmwareBusy;
    els.h3dUploadButton.disabled = !ready;

    let disabledReason = "";
    if (uploading) {
        els.h3dUploadButton.textContent = "Uploading...";
        disabledReason = "H3D upload is already in progress.";
    } else if (!serialSupported) {
        els.h3dUploadButton.textContent = "Web Serial unavailable";
        disabledReason = "Web Serial is not available in this browser.";
    } else if (!state.port) {
        els.h3dUploadButton.textContent = "Connect UART first";
        disabledReason = "Connect the UART before uploading an H3D image.";
    } else if (!state.h3dImage) {
        els.h3dUploadButton.textContent = "Select H3D image";
        disabledReason = "Select a packaged .h3d image first.";
    } else if (!ready) {
        els.h3dUploadButton.textContent = "UART busy";
        disabledReason = serialOperationDisabledReason();
    } else {
        els.h3dUploadButton.textContent = "Upload H3D";
    }
    setButtonDisabledReason(els.h3dUploadButton, disabledReason);
}

function setSerialOperation(operation) {
    state.serialOperation = operation;
    setConnectionUi(Boolean(state.port), state.port ? describePort(state.port) : "");
}

function clearSerialResponseWaiter(error = null) {
    const waiter = state.serialResponseWaiter;
    if (!waiter) {
        return;
    }

    window.clearTimeout(waiter.timeoutId);
    state.serialResponseWaiter = null;
    if (error) {
        waiter.reject(error);
    }
}

function waitForSerialResponse(markers, timeoutMs, description) {
    if (state.serialResponseWaiter) {
        return Promise.reject(new Error("another serial upload response is already pending"));
    }

    return new Promise((resolve, reject) => {
        const waiter = {
            buffer: "",
            markers,
            resolve,
            reject,
            timeoutId: window.setTimeout(() => {
                if (state.serialResponseWaiter !== waiter) {
                    return;
                }
                state.serialResponseWaiter = null;
                reject(new Error(`timed out waiting for ${description}`));
            }, timeoutMs),
        };
        state.serialResponseWaiter = waiter;
    });
}

function observeSerialResponse(bytes) {
    const waiter = state.serialResponseWaiter;
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
        state.serialResponseWaiter = null;
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
    clearUploadDiagnostic(els.h3dUploadDiagnostic);

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
    clearUploadDiagnostic(els.h3dUploadDiagnostic);
    appendSystem(
        `H3D upload: ${image.fileName}, payload=${image.imageBytes.toLocaleString()} bytes, ` +
        `CRC32=${formatHex32(image.payloadCrc32)}.`);

    try {
        const readyPromise = waitForSerialResponse(
            [H3D_READY_MARKER, H3D_ERROR_MARKER],
            H3D_RESPONSE_TIMEOUT_MS,
            "H3L READY");
        if (!await writeBytes(new Uint8Array([0x6c]))) {
            clearSerialResponseWaiter();
            throw new Error("could not send the H3D loader command");
        }
        const readyResult = await readyPromise;
        if (readyResult === H3D_ERROR_MARKER) {
            throw new Error("monitor reported an H3L error before receiving the header");
        }

        els.h3dProgressLabel.textContent = "Sending 64-byte header...";
        const dataPromise = waitForSerialResponse(
            [H3D_DATA_MARKER, H3D_ERROR_MARKER],
            H3D_RESPONSE_TIMEOUT_MS,
            "H3L DATA");
        if (!await writeBytes(image.packageBytes.subarray(0, image.headerBytes))) {
            clearSerialResponseWaiter();
            throw new Error("could not send the H3D header");
        }
        const dataResult = await dataPromise;
        if (dataResult === H3D_ERROR_MARKER) {
            throw new Error("monitor rejected the H3D header");
        }

        const wireMs = Math.ceil(
            (image.headerBytes + image.imageBytes) * 10 * 1000 / Number(els.baudRate.value));
        const resultPromise = waitForSerialResponse(
            [H3D_OK_MARKER, H3D_ERROR_MARKER],
            Math.max(H3D_RESULT_MARGIN_MS, wireMs + H3D_RESULT_MARGIN_MS),
            "H3L OK");

        let sent = 0;
        while (sent < image.payload.byteLength) {
            const end = Math.min(sent + H3D_UPLOAD_CHUNK_BYTES, image.payload.byteLength);
            if (!await writeBytes(image.payload.subarray(sent, end))) {
                clearSerialResponseWaiter();
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
        if (error.message === "timed out waiting for H3L READY") {
            showMonitorUploadDiagnostic(els.h3dUploadDiagnostic, "H3L");
        }
        appendSystem(
            `H3D upload failed: ${error.message}. ` +
            "Make sure the resident monitor prompt is active; stop Doom before retrying.");
    } finally {
        clearSerialResponseWaiter();
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


function validateWadVisibleName(name) {
    if (name.length < 5 || name.length >= 16) {
        throw new Error("WAD name must be 5-15 ASCII characters");
    }
    if (!name.toLowerCase().endsWith(".wad")) {
        throw new Error("WAD name must end in .wad");
    }
    if (!/^[A-Za-z0-9._-]+$/.test(name)) {
        throw new Error("WAD name may contain only letters, digits, '.', '_' and '-'");
    }
    if ([...name].some((character) => character.charCodeAt(0) > 0x7f)) {
        throw new Error("WAD name must contain ASCII characters only");
    }

    const encoded = new Uint8Array(16);
    encoded.set(new TextEncoder().encode(name));
    return encoded;
}

function validateIwad(bytes, profileName) {
    const profile = WAD_MEMORY_PROFILES[profileName];
    if (!profile) {
        throw new Error(`unknown memory profile ${profileName}`);
    }
    if (bytes.byteLength < 12) {
        throw new Error("file is shorter than a WAD header");
    }
    if (bytes.byteLength > profile.limit - profile.base) {
        const reservedMiB = (profile.limit - profile.base) / (1024 * 1024);
        throw new Error(`IWAD exceeds the reserved ${reservedMiB} MiB SDRAM region`);
    }
    if (String.fromCharCode(...bytes.subarray(0, 4)) !== "IWAD") {
        throw new Error("this milestone requires an IWAD file");
    }

    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const lumpCount = view.getUint32(4, true);
    const directoryOffset = view.getUint32(8, true);
    const directoryBytes = lumpCount * 16;

    if (lumpCount === 0 || directoryOffset > bytes.byteLength ||
        directoryBytes > bytes.byteLength - directoryOffset) {
        throw new Error("IWAD directory is outside the file");
    }

    for (let index = 0; index < lumpCount; ++index) {
        const entryOffset = directoryOffset + index * 16;
        const filePosition = view.getUint32(entryOffset, true);
        const lumpBytes = view.getUint32(entryOffset + 4, true);
        if (filePosition > bytes.byteLength || lumpBytes > bytes.byteLength - filePosition) {
            throw new Error(`IWAD lump ${index} is outside the file`);
        }
    }

    return { profile, lumpCount, directoryOffset };
}

function createWadHeader(bytes, visibleName, profileName, payloadCrc32) {
    const encodedName = validateWadVisibleName(visibleName);
    const { profile, lumpCount, directoryOffset } = validateIwad(bytes, profileName);
    if (payloadCrc32 === null || payloadCrc32 === undefined) {
        payloadCrc32 = crc32(bytes);
    }
    const header = new Uint8Array(WAD_HEADER_BYTES);
    const view = new DataView(header.buffer);
    const words = [
        WAD_PACKAGE_MAGIC,
        WAD_HEADER_BYTES,
        WAD_FORMAT_VERSION,
        WAD_FLAG_CRC32,
        profile.base,
        bytes.byteLength,
        payloadCrc32,
        0,
    ];
    words.forEach((value, index) => view.setUint32(index * 4, value, true));
    header.set(encodedName, 32);

    return {
        header,
        payload: bytes,
        payloadBytes: bytes.byteLength,
        payloadCrc32,
        loadAddress: profile.base,
        lumpCount,
        directoryOffset,
        visibleName,
        profileName,
    };
}

function updateWadUploaderUi() {
    const uploading = state.serialOperation === "wad-upload";
    const ready = Boolean(state.port && state.wadImage &&
        state.serialOperation === null && state.screenSnip === null &&
        !state.consoleFirmwareBusy);

    updateUploaderUartRequirement(
        els.wadUartRequirement,
        els.wadUartRequirementTitle,
        els.wadUartRequirementDetail,
        els.wadConnectUartButton,
        "H3W",
    );

    els.wadFileInput.disabled = uploading || state.consoleFirmwareBusy;
    els.wadVisibleName.disabled = uploading || state.consoleFirmwareBusy;
    els.wadMemoryProfile.disabled = uploading || state.consoleFirmwareBusy;
    els.wadLaunchAfterUpload.disabled = uploading || state.consoleFirmwareBusy;
    els.wadUploadButton.disabled = !ready;

    let disabledReason = "";
    if (uploading) {
        els.wadUploadButton.textContent = "Uploading...";
        disabledReason = "IWAD upload is already in progress.";
    } else if (!serialSupported) {
        els.wadUploadButton.textContent = "Web Serial unavailable";
        disabledReason = "Web Serial is not available in this browser.";
    } else if (!state.port) {
        els.wadUploadButton.textContent = "Connect UART first";
        disabledReason = "Connect the UART before uploading an IWAD.";
    } else if (!state.wadImage) {
        els.wadUploadButton.textContent = "Select IWAD";
        disabledReason = "Select a valid .wad file first.";
    } else if (!ready) {
        els.wadUploadButton.textContent = "UART busy";
        disabledReason = serialOperationDisabledReason();
    } else {
        els.wadUploadButton.textContent = "Upload IWAD";
    }
    setButtonDisabledReason(els.wadUploadButton, disabledReason);
}

function refreshWadImage() {
    state.wadImage = null;
    if (!state.wadBytes) {
        updateWadUploaderUi();
        return;
    }

    try {
        const image = createWadHeader(
            state.wadBytes,
            els.wadVisibleName.value.trim(),
            els.wadMemoryProfile.value,
            state.wadCrc32);
        state.wadImage = image;
        els.wadFileDetails.textContent =
            `${image.payloadBytes.toLocaleString()} bytes | ${image.lumpCount.toLocaleString()} lumps | ` +
            `directory ${formatHex32(image.directoryOffset)} | CRC32 ${formatHex32(image.payloadCrc32)} | ` +
            `load ${formatHex32(image.loadAddress)}`;
    } catch (error) {
        els.wadFileDetails.textContent = `Invalid IWAD: ${error.message}`;
    }

    updateWadUploaderUi();
}

async function selectWadFile() {
    state.wadBytes = null;
    state.wadCrc32 = null;
    state.wadImage = null;
    els.wadFileName.textContent = "No IWAD selected";
    els.wadFileDetails.textContent = "";
    els.wadProgress.value = 0;
    els.wadProgressLabel.textContent = "Idle";
    clearUploadDiagnostic(els.wadUploadDiagnostic);

    const file = els.wadFileInput.files?.[0];
    if (!file) {
        els.wadVisibleName.value = "";
        updateWadUploaderUi();
        return;
    }

    els.wadFileName.textContent = file.name;
    els.wadVisibleName.value = file.name.toLowerCase();
    els.wadFileDetails.textContent = "Validating IWAD directory and CRC32...";
    try {
        state.wadBytes = new Uint8Array(await file.arrayBuffer());
        validateIwad(state.wadBytes, els.wadMemoryProfile.value);
        state.wadCrc32 = crc32(state.wadBytes);
        refreshWadImage();
    } catch (error) {
        els.wadFileDetails.textContent = `Could not read IWAD: ${error.message}`;
        updateWadUploaderUi();
    }
}

async function uploadWadImage() {
    const image = state.wadImage;
    if (!state.port?.writable) {
        appendSystem("IWAD upload requires an open serial connection.");
        return;
    }
    if (!image) {
        appendSystem("Select a valid IWAD first.");
        return;
    }
    if (state.serialOperation !== null || state.screenSnip !== null) {
        appendSystem("Another serial operation is already in progress.");
        return;
    }

    const launchAfterUpload = els.wadLaunchAfterUpload.checked;
    let uploadSucceeded = false;
    const startedAt = performance.now();

    cancelScheduledScreenSnipProbe();
    stopScreenSnipCapabilityWatch();
    clearScreenSnipProbe();
    setScreenSnipCapability("checking");
    setSerialOperation("wad-upload");
    els.wadProgress.value = 0;
    els.wadProgressLabel.textContent = "Starting monitor IWAD loader...";
    clearUploadDiagnostic(els.wadUploadDiagnostic);
    appendSystem(
        `IWAD upload: ${image.visibleName}, profile=${image.profileName}, ` +
        `bytes=${image.payloadBytes.toLocaleString()}, lumps=${image.lumpCount.toLocaleString()}, ` +
        `CRC32=${formatHex32(image.payloadCrc32)}.`);

    try {
        const readyPromise = waitForSerialResponse(
            [WAD_READY_MARKER, WAD_ERROR_MARKER],
            WAD_RESPONSE_TIMEOUT_MS,
            "H3W READY");
        if (!await writeBytes(new Uint8Array([0x77]))) {
            clearSerialResponseWaiter();
            throw new Error("could not send the IWAD loader command");
        }
        const readyResult = await readyPromise;
        if (readyResult === WAD_ERROR_MARKER) {
            throw new Error("monitor reported an H3W error before receiving the header");
        }

        els.wadProgressLabel.textContent = "Sending 64-byte header...";
        const dataPromise = waitForSerialResponse(
            [WAD_DATA_MARKER, WAD_ERROR_MARKER],
            WAD_RESPONSE_TIMEOUT_MS,
            "H3W DATA");
        if (!await writeBytes(image.header)) {
            clearSerialResponseWaiter();
            throw new Error("could not send the IWAD header");
        }
        const dataResult = await dataPromise;
        if (dataResult === WAD_ERROR_MARKER) {
            throw new Error("monitor rejected the IWAD header");
        }

        const wireMs = Math.ceil(
            (WAD_HEADER_BYTES + image.payloadBytes) * 10 * 1000 / Number(els.baudRate.value));
        const resultPromise = waitForSerialResponse(
            [WAD_OK_MARKER, WAD_ERROR_MARKER],
            Math.max(WAD_RESULT_MARGIN_MS, wireMs + WAD_RESULT_MARGIN_MS),
            "H3W OK");

        let sent = 0;
        while (sent < image.payload.byteLength) {
            const end = Math.min(sent + WAD_UPLOAD_CHUNK_BYTES, image.payload.byteLength);
            if (!await writeBytes(image.payload.subarray(sent, end))) {
                clearSerialResponseWaiter();
                throw new Error("serial write failed during IWAD upload");
            }
            sent = end;
            const percent = sent * 100 / image.payload.byteLength;
            els.wadProgress.value = percent;
            els.wadProgressLabel.textContent =
                `${sent.toLocaleString()} / ${image.payload.byteLength.toLocaleString()} bytes ` +
                `(${percent.toFixed(1)}%)`;
        }

        const result = await resultPromise;
        if (result === WAD_ERROR_MARKER) {
            throw new Error("monitor reported an H3W upload error; see the UART terminal");
        }

        uploadSucceeded = true;
        els.wadProgress.value = 100;
        const elapsedSeconds = (performance.now() - startedAt) / 1000;
        els.wadProgressLabel.textContent = `Accepted in ${elapsedSeconds.toFixed(1)} s`;
        appendSystem(`IWAD upload accepted in ${elapsedSeconds.toFixed(1)} seconds.`);

        if (launchAfterUpload) {
            appendSystem("Launching the uploaded Doom image and IWAD with monitor command j.");
            await writeBytes(new Uint8Array([0x6a]));
        }
    } catch (error) {
        els.wadProgressLabel.textContent = `Failed: ${error.message}`;
        if (error.message === "timed out waiting for H3W READY") {
            showMonitorUploadDiagnostic(els.wadUploadDiagnostic, "H3W");
        }
        appendSystem(
            `IWAD upload failed: ${error.message}. ` +
            "Make sure the resident monitor prompt is active and the selected memory profile matches the monitor build.");
    } finally {
        clearSerialResponseWaiter();
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
    const interactive = connected && state.serialOperation === null &&
        !state.consoleFirmwareBusy;

    els.statusDot.classList.toggle("connected", connected);
    els.connectionStatus.textContent = connected ? "Connected" : "Not connected";
    els.serialPanelStatus.classList.toggle("connected", connected);
    els.serialPanelStatus.classList.toggle("error", !connected && Boolean(state.uartConnectionIssue));
    if (connected) {
        els.serialPanelStatus.textContent = "UART connected";
    } else if (state.uartConnecting) {
        els.serialPanelStatus.textContent = "Connecting UART";
    } else if (state.uartConnectionIssue) {
        els.serialPanelStatus.textContent = "UART unavailable";
    } else {
        els.serialPanelStatus.textContent = "UART disconnected";
    }
    if (connected) {
        els.connectButton.textContent = "Disconnect";
    } else if (state.uartConnecting) {
        els.connectButton.textContent = "Connecting...";
    } else if (state.uartConnectionIssue) {
        els.connectButton.textContent = "Retry";
    } else {
        els.connectButton.textContent = "Connect";
    }
    els.connectButton.disabled = state.serialOperation !== null ||
        state.consoleFirmwareBusy || state.uartConnecting;
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
    els.reconnectButton.disabled = connected || state.authorizedPorts.length === 0 ||
        state.uartConnecting || state.serialOperation !== null || state.consoleFirmwareBusy;

    let connectDisabledReason = "";
    if (state.uartConnecting) {
        connectDisabledReason = "A UART connection is already in progress.";
    } else if (state.consoleFirmwareBusy) {
        connectDisabledReason = "Wait for console firmware loading to finish.";
    } else if (state.serialOperation !== null) {
        connectDisabledReason = serialOperationDisabledReason();
    }
    setButtonDisabledReason(els.connectButton, connectDisabledReason);

    let reconnectDisabledReason = "";
    if (connected) {
        reconnectDisabledReason = "UART is already connected. Disconnect it before reconnecting an authorized port.";
    } else if (state.uartConnecting) {
        reconnectDisabledReason = "A UART connection is already in progress.";
    } else if (state.serialOperation !== null || state.consoleFirmwareBusy) {
        reconnectDisabledReason = serialOperationDisabledReason();
    } else if (state.authorizedPorts.length === 0) {
        reconnectDisabledReason = "No previously authorized serial ports are available. Use Connect to choose a port.";
    }
    setButtonDisabledReason(els.reconnectButton, reconnectDisabledReason);

    const interactiveDisabledReason = connected
        ? serialOperationDisabledReason()
        : "Connect the UART first.";
    setButtonDisabledReason(els.sendButton, interactiveDisabledReason);
    setButtonDisabledReason(els.macroSendButton, interactiveDisabledReason);
    document.querySelectorAll(".command-button").forEach((button) => {
        if (!button.dataset.enabledTitleCaptured) {
            button.dataset.enabledTitle = button.getAttribute("title") || "";
            button.dataset.enabledTitleCaptured = "1";
        }
        if (button.disabled) {
            button.title = interactiveDisabledReason;
        } else if (button.dataset.enabledTitle) {
            button.title = button.dataset.enabledTitle;
        } else {
            button.removeAttribute("title");
        }
    });

    if (detail) {
        els.portDetails.textContent = detail;
    } else if (!connected) {
        updateAuthorizedPortDetails();
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

    if (state.uartConnecting) {
        els.portDetails.textContent = "Connecting to the selected serial port...";
        return;
    }

    if (state.uartConnectionIssue) {
        els.portDetails.textContent = `${state.uartConnectionIssue.title}: ${state.uartConnectionIssue.detail}`;
        return;
    }

    if (anotherDeviceToolOwnsUart()) {
        els.portDetails.textContent = "Another Device Tool page from this site currently owns the UART. Disconnect it there before connecting here.";
        return;
    }

    const duplicateNote = otherDeviceToolPageCount() !== 0
        ? " Another Device Tool page is also open; only one page can own the UART."
        : "";

    if (state.authorizedPorts.length === 0) {
        els.portDetails.textContent = "No authorized serial ports. Click Connect to choose one." + duplicateNote;
        return;
    }

    const selectedIndex = Number(els.authorizedPort.value);
    const selectedPort = state.authorizedPorts[selectedIndex];
    if (!selectedPort) {
        els.portDetails.textContent = `${state.authorizedPorts.length} authorized serial ports are available.` + duplicateNote;
        return;
    }

    const suffix = state.authorizedPorts.length === 1
        ? "Click Connect to grant/select another port."
        : "Choose a port above, then click Reconnect.";
    els.portDetails.textContent = `${portIdentity(selectedPort, selectedIndex)}. ${suffix}` + duplicateNote;
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

    els.authorizedPort.disabled = Boolean(state.port) || ports.length === 0 ||
        state.uartConnecting;
    els.reconnectButton.disabled = Boolean(state.port) || ports.length === 0 ||
        state.uartConnecting || state.serialOperation !== null || state.consoleFirmwareBusy;
    let reconnectDisabledReason = "";
    if (state.port) {
        reconnectDisabledReason = "UART is already connected. Disconnect it before reconnecting an authorized port.";
    } else if (state.uartConnecting) {
        reconnectDisabledReason = "A UART connection is already in progress.";
    } else if (state.serialOperation !== null || state.consoleFirmwareBusy) {
        reconnectDisabledReason = serialOperationDisabledReason();
    } else if (ports.length === 0) {
        reconnectDisabledReason = "No previously authorized serial ports are available. Use Connect to choose a port.";
    }
    setButtonDisabledReason(els.reconnectButton, reconnectDisabledReason);
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
    observeSerialResponse(bytes);

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

    const lockAcquired = await acquireUartLock();
    if (!lockAcquired) {
        throw new UartOwnershipError(
            "Another Hazard3-Doom Device Tool page already owns the UART.");
    }

    try {
        await port.open(serialOptions());
    } catch (error) {
        releaseUartLock();
        throw error;
    }
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
    clearUartConnectionIssue();
    broadcastDeviceToolState("uart-owner");
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

    clearUartConnectionIssue();
    state.uartConnecting = true;
    setConnectionUi(false);

    try {
        const port = await navigator.serial.requestPort();
        await refreshAuthorizedPorts(port);
        await openPort(port);
    } catch (error) {
        if (error.name !== "NotFoundError") {
            setUartConnectionIssue(error);
            appendSystem(`Connect failed: ${error.message}`);
        }
    } finally {
        state.uartConnecting = false;
        setConnectionUi(Boolean(state.port), state.port ? describePort(state.port) : "");
    }
}

async function reconnect() {
    if (!serialSupported || state.port) {
        return;
    }

    clearUartConnectionIssue();
    state.uartConnecting = true;
    setConnectionUi(false);

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
        setUartConnectionIssue(error);
        appendSystem(`Reconnect failed: ${error.message}`);
    } finally {
        state.uartConnecting = false;
        setConnectionUi(Boolean(state.port), state.port ? describePort(state.port) : "");
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
    clearSerialResponseWaiter(new Error("serial connection closed"));
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
        releaseUartLock();
        broadcastDeviceToolState("uart-owner");
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

function clampTerminalHeight(height, maximum = TERMINAL_MAX_MANUAL_HEIGHT_PX) {
    return Math.max(TERMINAL_MIN_HEIGHT_PX, Math.min(maximum, height));
}

function calculateAutoTerminalHeight() {
    if (!window.matchMedia("(min-width: 921px)").matches) {
        const stackedHeight = Math.max(240, window.innerHeight * 0.52);
        return clampTerminalHeight(stackedHeight, TERMINAL_MAX_AUTO_HEIGHT_PX);
    }

    const panelRect = els.terminalPanel.getBoundingClientRect();
    const nonTerminalHeight = Math.max(0, els.terminalPanel.offsetHeight - els.terminal.offsetHeight);
    const availablePanelHeight = window.innerHeight - panelRect.top - TERMINAL_VIEWPORT_MARGIN_PX;
    const availableTerminalHeight = availablePanelHeight - nonTerminalHeight;

    return clampTerminalHeight(availableTerminalHeight, TERMINAL_MAX_AUTO_HEIGHT_PX);
}

function setTerminalHeight(height) {
    const maximum = Math.max(TERMINAL_MIN_HEIGHT_PX,
        Math.min(TERMINAL_MAX_MANUAL_HEIGHT_PX, window.innerHeight * 1.5));
    const clampedHeight = clampTerminalHeight(height, maximum);

    els.terminal.style.height = `${Math.round(clampedHeight)}px`;
    if (window.matchMedia("(min-width: 921px)").matches) {
        els.controlsPanel.style.height = `${Math.round(els.terminalPanel.getBoundingClientRect().height)}px`;
    } else {
        els.controlsPanel.style.removeProperty("height");
    }
    els.terminalResizeHandle.setAttribute("aria-valuenow", String(Math.round(clampedHeight)));
    els.terminalResizeHandle.setAttribute("aria-valuemax", String(Math.round(maximum)));
}

function fitTerminalToViewport() {
    const autoHeight = calculateAutoTerminalHeight();
    setTerminalHeight(autoHeight + state.terminalHeightOffset);
}

function scheduleTerminalFit() {
    if (state.terminalResizeFrame !== null) {
        window.cancelAnimationFrame(state.terminalResizeFrame);
    }

    state.terminalResizeFrame = window.requestAnimationFrame(() => {
        state.terminalResizeFrame = null;
        fitTerminalToViewport();
    });
}

function resetTerminalHeight() {
    state.terminalHeightOffset = 0;
    scheduleTerminalFit();
}

function wireTerminalResize() {
    let dragStartY = 0;
    let dragStartHeight = 0;
    let dragging = false;

    const finishDrag = (event) => {
        if (!dragging) {
            return;
        }

        dragging = false;
        document.body.classList.remove("terminal-resizing");
        if (els.terminalResizeHandle.hasPointerCapture?.(event.pointerId)) {
            els.terminalResizeHandle.releasePointerCapture(event.pointerId);
        }
    };

    els.terminalResizeHandle.addEventListener("pointerdown", (event) => {
        if (event.button !== 0) {
            return;
        }

        dragging = true;
        dragStartY = event.clientY;
        dragStartHeight = els.terminal.getBoundingClientRect().height;
        document.body.classList.add("terminal-resizing");
        els.terminalResizeHandle.setPointerCapture?.(event.pointerId);
        event.preventDefault();
    });

    els.terminalResizeHandle.addEventListener("pointermove", (event) => {
        if (!dragging) {
            return;
        }

        const desiredHeight = dragStartHeight + event.clientY - dragStartY;
        const autoHeight = calculateAutoTerminalHeight();
        const maximum = Math.max(TERMINAL_MIN_HEIGHT_PX,
            Math.min(TERMINAL_MAX_MANUAL_HEIGHT_PX, window.innerHeight * 1.5));
        const clampedHeight = clampTerminalHeight(desiredHeight, maximum);

        state.terminalHeightOffset = clampedHeight - autoHeight;
        setTerminalHeight(clampedHeight);
        event.preventDefault();
    });

    els.terminalResizeHandle.addEventListener("pointerup", finishDrag);
    els.terminalResizeHandle.addEventListener("pointercancel", finishDrag);
    els.terminalResizeHandle.addEventListener("dblclick", resetTerminalHeight);
    els.terminalResizeHandle.addEventListener("keydown", (event) => {
        const step = event.shiftKey ? 80 : 24;

        if (event.key === "Home") {
            event.preventDefault();
            resetTerminalHeight();
            return;
        }
        if (event.key !== "ArrowUp" && event.key !== "ArrowDown") {
            return;
        }

        event.preventDefault();
        state.terminalHeightOffset += event.key === "ArrowDown" ? step : -step;
        fitTerminalToViewport();
    });

    window.addEventListener("resize", scheduleTerminalFit);
    window.visualViewport?.addEventListener("resize", scheduleTerminalFit);
    window.addEventListener("load", scheduleTerminalFit);

    document.querySelectorAll("details").forEach((details) => {
        details.addEventListener("toggle", scheduleTerminalFit);
    });

    if ("ResizeObserver" in window) {
        state.terminalLayoutObserver = new ResizeObserver(scheduleTerminalFit);
        document.querySelectorAll(".app-header, .upload-panel, .serial-panel").forEach((element) => {
            state.terminalLayoutObserver.observe(element);
        });
    }

    scheduleTerminalFit();
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
    document.querySelectorAll(".serial-header-actions, .flasher-header-actions").forEach((actions) => {
        actions.addEventListener("click", (event) => {
            event.stopPropagation();
        });
    });

    els.connectButton.addEventListener("click", connect);
    els.reconnectButton.addEventListener("click", reconnect);
    els.authorizedPort.addEventListener("change", updateAuthorizedPortDetails);
    els.clearButton.addEventListener("click", clearTerminal);
    els.downloadButton.addEventListener("click", downloadLog);
    els.copyButton.addEventListener("click", copyTerminalContents);
    els.screenSnipButton.addEventListener("click", requestScreenSnip);
    els.firmwareFileInput.addEventListener("change", selectConsoleFirmwareFile);
    els.firmwareUploadButton.addEventListener("click", loadConsoleFirmware);
    els.firmwareLoaderRefreshButton.addEventListener("click", () => {
        void checkConsoleFirmwareLoader();
    });
    els.firmwareLoaderAccessKey.addEventListener("input", updateConsoleFirmwareAccessKey);
    els.firmwareLoaderAccessKey.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
            event.preventDefault();
            void checkConsoleFirmwareLoader();
        }
    });
    els.h3dFileInput.addEventListener("change", selectH3dFile);
    els.h3dUploadButton.addEventListener("click", uploadH3dImage);
    els.h3dConnectUartButton.addEventListener("click", connect);
    els.wadFileInput.addEventListener("change", selectWadFile);
    els.wadVisibleName.addEventListener("input", refreshWadImage);
    els.wadMemoryProfile.addEventListener("change", refreshWadImage);
    els.wadUploadButton.addEventListener("click", uploadWadImage);
    els.wadConnectUartButton.addEventListener("click", connect);

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
        broadcastDeviceToolState("goodbye");
        releaseUartLock();
        if (state.deviceToolHeartbeatTimer !== null) {
            window.clearInterval(state.deviceToolHeartbeatTimer);
        }
    });
}

async function initialize() {
    updateAppVersion();
    loadSettings();
    wireEvents();
    wireTerminalResize();
    setConnectionUi(false);
    startDeviceToolCoordination();
    updateConsoleFirmwareUi();
    void checkConsoleFirmwareLoader();

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
