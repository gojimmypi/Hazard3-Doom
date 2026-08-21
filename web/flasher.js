"use strict";

(() => {
    const FTDI_VENDOR_ID = 0x0403;
    const ULX3S_FT231X_PRODUCT_ID = 0x6015;

    const FTDI = Object.freeze({
        SIO_RESET: 0x00,
        SIO_SET_FLOW_CTRL: 0x02,
        SIO_SET_BAUD_RATE: 0x03,
        SIO_SET_LATENCY_TIMER: 0x09,
        SIO_SET_BITMODE: 0x0b,
        RESET_SIO: 0,
        PURGE_RX: 1,
        PURGE_TX: 2,
        BITMODE_RESET: 0x00,
        BITMODE_SYNCBB: 0x04,
        BAUD_DIVISOR_1M: 3
    });

    // ULX3S FT231X bit-bang/JTAG mapping used by fujprog.
    const JTAG_PIN = Object.freeze({
        TCK: 0x20,
        TMS: 0x40,
        TDI: 0x80,
        TDO: 0x08
    });

    const ECP5_IDCODES = new Map([
        [0x21111043, "LFE5U-12F"],
        [0x41111043, "LFE5U-25F"],
        [0x41112043, "LFE5U-45F"],
        [0x41113043, "LFE5U-85F"]
    ]);

    const TAP = Object.freeze({
        RESET: "RESET",
        IDLE: "IDLE",
        DRSELECT: "DRSELECT",
        DRCAPTURE: "DRCAPTURE",
        DRSHIFT: "DRSHIFT",
        DREXIT1: "DREXIT1",
        DRPAUSE: "DRPAUSE",
        DREXIT2: "DREXIT2",
        DRUPDATE: "DRUPDATE",
        IRSELECT: "IRSELECT",
        IRCAPTURE: "IRCAPTURE",
        IRSHIFT: "IRSHIFT",
        IREXIT1: "IREXIT1",
        IRPAUSE: "IRPAUSE",
        IREXIT2: "IREXIT2",
        IRUPDATE: "IRUPDATE"
    });

    const TAP_ALIASES = Object.freeze({
        TEST_LOGIC_RESET: TAP.RESET,
        RUN_TEST_IDLE: TAP.IDLE,
        SELECT_DR_SCAN: TAP.DRSELECT,
        CAPTURE_DR: TAP.DRCAPTURE,
        SHIFT_DR: TAP.DRSHIFT,
        EXIT1_DR: TAP.DREXIT1,
        PAUSE_DR: TAP.DRPAUSE,
        EXIT2_DR: TAP.DREXIT2,
        UPDATE_DR: TAP.DRUPDATE,
        SELECT_IR_SCAN: TAP.IRSELECT,
        CAPTURE_IR: TAP.IRCAPTURE,
        SHIFT_IR: TAP.IRSHIFT,
        EXIT1_IR: TAP.IREXIT1,
        PAUSE_IR: TAP.IRPAUSE,
        EXIT2_IR: TAP.IREXIT2,
        UPDATE_IR: TAP.IRUPDATE,
        RESET: TAP.RESET,
        IDLE: TAP.IDLE,
        DRSELECT: TAP.DRSELECT,
        DRCAPTURE: TAP.DRCAPTURE,
        DRSHIFT: TAP.DRSHIFT,
        DREXIT1: TAP.DREXIT1,
        DRPAUSE: TAP.DRPAUSE,
        DREXIT2: TAP.DREXIT2,
        DRUPDATE: TAP.DRUPDATE,
        IRSELECT: TAP.IRSELECT,
        IRCAPTURE: TAP.IRCAPTURE,
        IRSHIFT: TAP.IRSHIFT,
        IREXIT1: TAP.IREXIT1,
        IRPAUSE: TAP.IRPAUSE,
        IREXIT2: TAP.IREXIT2,
        IRUPDATE: TAP.IRUPDATE
    });

    const TAP_NEXT = Object.freeze({
        [TAP.RESET]: [TAP.IDLE, TAP.RESET],
        [TAP.IDLE]: [TAP.IDLE, TAP.DRSELECT],
        [TAP.DRSELECT]: [TAP.DRCAPTURE, TAP.IRSELECT],
        [TAP.DRCAPTURE]: [TAP.DRSHIFT, TAP.DREXIT1],
        [TAP.DRSHIFT]: [TAP.DRSHIFT, TAP.DREXIT1],
        [TAP.DREXIT1]: [TAP.DRPAUSE, TAP.DRUPDATE],
        [TAP.DRPAUSE]: [TAP.DRPAUSE, TAP.DREXIT2],
        [TAP.DREXIT2]: [TAP.DRSHIFT, TAP.DRUPDATE],
        [TAP.DRUPDATE]: [TAP.IDLE, TAP.DRSELECT],
        [TAP.IRSELECT]: [TAP.IRCAPTURE, TAP.RESET],
        [TAP.IRCAPTURE]: [TAP.IRSHIFT, TAP.IREXIT1],
        [TAP.IRSHIFT]: [TAP.IRSHIFT, TAP.IREXIT1],
        [TAP.IREXIT1]: [TAP.IRPAUSE, TAP.IRUPDATE],
        [TAP.IRPAUSE]: [TAP.IRPAUSE, TAP.IREXIT2],
        [TAP.IREXIT2]: [TAP.IRSHIFT, TAP.IRUPDATE],
        [TAP.IRUPDATE]: [TAP.IDLE, TAP.DRSELECT]
    });

    const els = {
        section: document.getElementById("fpgaFlasher"),
        unsupported: document.getElementById("flasherUnsupportedNotice"),
        deviceStatus: document.getElementById("flasherDeviceStatus"),
        fileInput: document.getElementById("svfFileInput"),
        fileName: document.getElementById("svfFileName"),
        fileDetails: document.getElementById("svfFileDetails"),
        connectButton: document.getElementById("flasherConnectButton"),
        probeButton: document.getElementById("flasherProbeButton"),
        programButton: document.getElementById("flasherProgramButton"),
        disconnectButton: document.getElementById("flasherDisconnectButton"),
        progress: document.getElementById("flasherProgress"),
        progressLabel: document.getElementById("flasherProgressLabel"),
        log: document.getElementById("flasherLog"),
        autoScroll: document.getElementById("flasherAutoScroll"),
        copyLogButton: document.getElementById("flasherCopyLogButton"),
        copyLogButtonLabel: document.getElementById("flasherCopyLogButtonLabel"),
        clearLogButton: document.getElementById("flasherClearLogButton"),
        idcode: document.getElementById("flasherIdcode")
    };

    if (!els.section) {
        return;
    }

    const webUsbSupported = "usb" in navigator;
    const state = {
        transport: null,
        tap: null,
        file: null,
        svfText: "",
        busy: false,
        idcode: null,
        idName: ""
    };

    function setBusy(busy) {
        state.busy = busy;
        els.fileInput.disabled = busy;
        els.connectButton.disabled = busy || !webUsbSupported || !!state.transport;
        els.disconnectButton.disabled = busy || !state.transport;
        els.probeButton.disabled = busy || !state.transport;
        els.programButton.disabled = busy || !state.transport || !state.svfText;
    }

    function setProgress(percent, label) {
        const safePercent = Math.max(0, Math.min(100, Math.round(percent)));
        els.progress.value = safePercent;
        els.progressLabel.textContent = label || `${safePercent}%`;
    }

    function appendLog(message, level = "info") {
        const now = new Date();
        const stamp = now.toLocaleTimeString([], {hour12: false});
        const prefix = level === "error" ? "ERROR" : level === "ok" ? "OK" : "INFO";
        els.log.textContent += `[${stamp}] ${prefix}: ${message}\n`;
        if (!els.autoScroll || els.autoScroll.checked) {
            els.log.scrollTop = els.log.scrollHeight;
        }
    }

    function clearFlasherLog() {
        els.log.textContent = "";
        els.log.scrollTop = 0;
    }

    function copyFlasherLogFallback(text) {
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

    async function copyFlasherLog() {
        const text = els.log.textContent;
        const originalLabel = els.copyLogButtonLabel.textContent;

        try {
            if (navigator.clipboard?.writeText && window.isSecureContext) {
                await navigator.clipboard.writeText(text);
            } else {
                copyFlasherLogFallback(text);
            }
            els.copyLogButtonLabel.textContent = "Copied";
            els.copyLogButton.classList.add("copy-success");
        } catch (error) {
            console.error("Could not copy FPGA flasher log:", error);
            els.copyLogButtonLabel.textContent = "Copy failed";
        }

        window.setTimeout(() => {
            els.copyLogButtonLabel.textContent = originalLabel;
            els.copyLogButton.classList.remove("copy-success");
        }, 1200);
    }

    function isWindowsHost() {
        const platform = navigator.userAgentData?.platform || navigator.platform || navigator.userAgent || "";
        return /win/i.test(platform);
    }

    function isUsbAccessDenied(error) {
        const name = String(error?.name || "").toLowerCase();
        const message = String(error?.message || error || "").toLowerCase();
        return name === "notallowederror" ||
            message.includes("access denied") ||
            message.includes("permission denied");
    }

    function appendWindowsDriverHint(error) {
        if (!isWindowsHost() || !isUsbAccessDenied(error)) {
            return false;
        }
        appendLog("Detected a Windows WebUSB driver access failure for ULX3S US1.", "error");
        appendLog("Bind the ULX3S FT231X interface to the WinUSB driver (for example with Zadig), then unplug/replug US1 and reconnect.");
        appendLog("While WinUSB is installed, the normal FTDI VCP/D2XX COM-port driver for US1 is not available. If WinUSB is already installed, close other USB/JTAG tools and reconnect the board.");
        return true;
    }

    function clearIdcode() {
        state.idcode = null;
        state.idName = "";
        els.idcode.textContent = "Not probed";
        els.idcode.classList.remove("ok", "error");
    }

    function formatIdcode(value) {
        return `0x${value.toString(16).toUpperCase().padStart(8, "0")}`;
    }

    function normalizeTapState(value) {
        const key = String(value || "").trim().toUpperCase().replaceAll("-", "_");
        const normalized = TAP_ALIASES[key];
        if (!normalized) {
            throw new Error(`Unsupported TAP state: ${value}`);
        }
        return normalized;
    }

    function getHexBit(hex, bitIndex) {
        const nibbleIndex = hex.length - 1 - Math.floor(bitIndex / 4);
        if (nibbleIndex < 0) {
            return 0;
        }
        const nibble = Number.parseInt(hex[nibbleIndex], 16);
        if (!Number.isFinite(nibble)) {
            throw new Error("SVF contains non-hexadecimal scan data.");
        }
        return (nibble >> (bitIndex & 3)) & 1;
    }

    function bitsToHex(bits) {
        let result = "";
        for (let offset = 0; offset < bits.length; offset += 4) {
            let nibble = 0;
            for (let bit = 0; bit < 4 && offset + bit < bits.length; bit++) {
                nibble |= bits[offset + bit] << bit;
            }
            result = nibble.toString(16).toUpperCase() + result;
        }
        return result || "0";
    }

    function parseScanCommand(command) {
        const head = command.match(/^\s*(SIR|SDR)\s+(\d+)\b/i);
        if (!head) {
            return null;
        }

        const fields = {};
        const fieldRegex = /\b(TDI|TDO|MASK|SMASK)\s*\(\s*([0-9a-fA-F\s]+?)\s*\)/gi;
        let match;
        while ((match = fieldRegex.exec(command)) !== null) {
            fields[match[1].toUpperCase()] = match[2].replace(/\s+/g, "").toUpperCase();
        }

        const bitCount = Number.parseInt(head[2], 10);
        const requiredHexChars = Math.ceil(bitCount / 4);
        if (!fields.TDI) {
            throw new Error(`${head[1].toUpperCase()} is missing TDI data.`);
        }
        if (fields.TDI.length !== requiredHexChars) {
            throw new Error(`${head[1].toUpperCase()} ${bitCount} expects ${requiredHexChars} TDI hex digits, got ${fields.TDI.length}.`);
        }
        for (const name of ["TDO", "MASK", "SMASK"]) {
            if (fields[name] && fields[name].length !== requiredHexChars) {
                throw new Error(`${head[1].toUpperCase()} ${name} length does not match ${bitCount} bits.`);
            }
        }

        return {
            type: head[1].toUpperCase(),
            bitCount,
            tdi: fields.TDI,
            tdo: fields.TDO || null,
            mask: fields.MASK || null,
            smask: fields.SMASK || null
        };
    }

    function splitSvfCommands(text) {
        const withoutLineComments = text
            .replace(/\/\/.*$/gm, "")
            .replace(/!.*$/gm, "");
        const commands = [];
        let start = 0;
        for (let i = 0; i < withoutLineComments.length; i++) {
            if (withoutLineComments[i] !== ";") {
                continue;
            }
            const body = withoutLineComments.slice(start, i).trim();
            if (body) {
                commands.push({text: body, endOffset: i + 1});
            }
            start = i + 1;
        }
        const tail = withoutLineComments.slice(start).trim();
        if (tail) {
            throw new Error("SVF ends with an unterminated command (missing ';').");
        }
        return {commands, totalLength: Math.max(1, withoutLineComments.length)};
    }

    function reverseByte(value) {
        let result = 0;
        for (let bit = 0; bit < 8; bit++) {
            if ((value >> (7 - bit)) & 1) {
                result |= 1 << bit;
            }
        }
        return result;
    }

    function bitstreamIdcode(bytes) {
        const marker = [0xE2, 0x00, 0x00, 0x00];
        for (let i = 0; i + 7 < bytes.length; i++) {
            if (bytes[i] !== marker[0] || bytes[i + 1] !== marker[1] ||
                bytes[i + 2] !== marker[2] || bytes[i + 3] !== marker[3]) {
                continue;
            }
            return (
                (bytes[i + 4] << 24) |
                (bytes[i + 5] << 16) |
                (bytes[i + 6] << 8) |
                bytes[i + 7]
            ) >>> 0;
        }
        return null;
    }

    function bitstreamToSvf(bytes) {
        const idcode = bitstreamIdcode(bytes);
        if (idcode === null) {
            throw new Error("Could not find an ECP5 IDCODE command in the .bit file.");
        }
        if (!ECP5_IDCODES.has(idcode)) {
            throw new Error(`Bitstream targets unsupported ECP5 ID ${formatIdcode(idcode)}.`);
        }

        const lines = [
            "HDR 0;",
            "HIR 0;",
            "TDR 0;",
            "TIR 0;",
            "ENDDR DRPAUSE;",
            "ENDIR IRPAUSE;",
            "STATE IDLE;",
            `SIR 8 TDI (E0);`,
            `SDR 32 TDI (00000000) TDO (${formatIdcode(idcode).slice(2)}) MASK (FFFFFFFF);`,
            "SIR 8 TDI (1C);",
            "SDR 510 TDI (3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);",
            "SIR 8 TDI (C6);",
            "SDR 8 TDI (00);",
            "RUNTEST IDLE 2 TCK 1.00E-02 SEC;",
            "SIR 8 TDI (3C);",
            "SDR 32 TDI (00000000) TDO (00000000) MASK (0000B000);",
            "SIR 8 TDI (46);",
            "SDR 8 TDI (01);",
            "RUNTEST IDLE 2 TCK 1.00E-02 SEC;",
            "SIR 8 TDI (7A);",
            "RUNTEST IDLE 2 TCK 1.00E-02 SEC;"
        ];

        const maxChunkBytes = 1000;
        for (let offset = 0; offset < bytes.length; offset += maxChunkBytes) {
            const chunk = bytes.subarray(offset, Math.min(bytes.length, offset + maxChunkBytes));
            let hex = "";
            for (let i = chunk.length - 1; i >= 0; i--) {
                hex += reverseByte(chunk[i]).toString(16).toUpperCase().padStart(2, "0");
            }
            lines.push(`SDR ${chunk.length * 8} TDI (${hex});`);
        }

        lines.push(
            "SIR 8 TDI (FF);",
            "RUNTEST IDLE 100 TCK 1.00E-02 SEC;",
            "SIR 8 TDI (C0);",
            "RUNTEST IDLE 2 TCK 1.00E-03 SEC;",
            "SDR 32 TDI (00000000) TDO (00000000) MASK (FFFFFFFF);",
            "SIR 8 TDI (26);",
            "RUNTEST IDLE 2 TCK 2.00E-01 SEC;",
            "SIR 8 TDI (FF);",
            "RUNTEST IDLE 2 TCK 1.00E-03 SEC;",
            "SIR 8 TDI (3C);",
            "SDR 32 TDI (00000000) TDO (00000100) MASK (00002100);"
        );

        return {
            svfText: `${lines.join("\n")}\n`,
            idcode
        };
    }

    class FtdiWebUsbTransport {
        constructor(device) {
            this.device = device;
            this.interfaceNumber = null;
            this.channelIndex = null;
            this.inEndpoint = null;
            this.outEndpoint = null;
            this.inPacketSize = 64;
        }

        async controlOut(request, value = 0, index = this.channelIndex || 0) {
            const result = await this.device.controlTransferOut({
                requestType: "vendor",
                recipient: "device",
                request,
                value,
                index
            });
            if (result.status !== "ok") {
                throw new Error(`FTDI control request 0x${request.toString(16)} failed (${result.status}).`);
            }
        }

        async open() {
            if (!this.device.opened) {
                await this.device.open();
            }
            if (!this.device.configuration) {
                await this.device.selectConfiguration(1);
            }

            let selected = null;
            for (const usbInterface of this.device.configuration.interfaces) {
                for (const alternate of usbInterface.alternates) {
                    const inEndpoint = alternate.endpoints.find((endpoint) => endpoint.type === "bulk" && endpoint.direction === "in");
                    const outEndpoint = alternate.endpoints.find((endpoint) => endpoint.type === "bulk" && endpoint.direction === "out");
                    if (inEndpoint && outEndpoint) {
                        selected = {usbInterface, alternate, inEndpoint, outEndpoint};
                        break;
                    }
                }
                if (selected) {
                    break;
                }
            }

            if (!selected) {
                throw new Error("The selected FTDI device does not expose the expected bulk USB endpoints.");
            }

            this.interfaceNumber = selected.usbInterface.interfaceNumber;
            this.channelIndex = this.interfaceNumber + 1;
            try {
                await this.device.claimInterface(this.interfaceNumber);
            } catch (error) {
                throw new Error(`Could not claim the ULX3S FT231X interface: ${error.message}. Close fujprog/OpenOCD and ensure the browser has direct USB driver access.`);
            }
            if (selected.alternate.alternateSetting !== 0) {
                await this.device.selectAlternateInterface(this.interfaceNumber, selected.alternate.alternateSetting);
            }

            this.inEndpoint = selected.inEndpoint.endpointNumber;
            this.outEndpoint = selected.outEndpoint.endpointNumber;
            this.inPacketSize = selected.inEndpoint.packetSize || 64;

            await this.controlOut(FTDI.SIO_RESET, FTDI.RESET_SIO);
            await this.controlOut(FTDI.SIO_RESET, FTDI.PURGE_RX);
            await this.controlOut(FTDI.SIO_RESET, FTDI.PURGE_TX);
            await this.controlOut(FTDI.SIO_SET_FLOW_CTRL, 0);
            await this.controlOut(FTDI.SIO_SET_BAUD_RATE, FTDI.BAUD_DIVISOR_1M, 0);
            await this.controlOut(FTDI.SIO_SET_LATENCY_TIMER, 1);
            await this.setBitMode(JTAG_PIN.TCK | JTAG_PIN.TMS | JTAG_PIN.TDI, FTDI.BITMODE_SYNCBB);
            await new Promise((resolve) => setTimeout(resolve, 20));
            await this.controlOut(FTDI.SIO_RESET, FTDI.PURGE_RX);
        }

        async setBitMode(mask, mode) {
            await this.controlOut(FTDI.SIO_SET_BITMODE, (mode << 8) | mask);
        }

        stripFtdiStatus(raw) {
            const result = [];
            for (let offset = 0; offset < raw.length; offset += this.inPacketSize) {
                const packetLength = Math.min(this.inPacketSize, raw.length - offset);
                if (packetLength <= 2) {
                    continue;
                }
                for (let i = offset + 2; i < offset + packetLength; i++) {
                    result.push(raw[i]);
                }
            }
            return result;
        }

        async readSamples(expectedBytes) {
            const samples = [];
            let emptyReads = 0;
            while (samples.length < expectedBytes) {
                const remaining = expectedBytes - samples.length;
                const payloadPerPacket = Math.max(1, this.inPacketSize - 2);
                const packetsNeeded = Math.max(1, Math.ceil(remaining / payloadPerPacket));
                const requestBytes = Math.min(16384, packetsNeeded * this.inPacketSize);
                const result = await this.device.transferIn(this.inEndpoint, requestBytes);
                if (result.status !== "ok") {
                    throw new Error(`FTDI bulk read failed (${result.status}).`);
                }
                const raw = result.data ? new Uint8Array(result.data.buffer, result.data.byteOffset, result.data.byteLength) : new Uint8Array();
                const decoded = this.stripFtdiStatus(raw);
                if (decoded.length === 0) {
                    emptyReads++;
                    if (emptyReads > 12) {
                        throw new Error(`Timed out waiting for ${remaining} FTDI synchronous samples.`);
                    }
                    await new Promise((resolve) => setTimeout(resolve, 2));
                    continue;
                }
                emptyReads = 0;
                samples.push(...decoded);
            }
            return Uint8Array.from(samples.slice(0, expectedBytes));
        }

        async exchange(outputBytes) {
            const MAX_CHUNK = 384;
            const received = new Uint8Array(outputBytes.length);
            for (let offset = 0; offset < outputBytes.length; offset += MAX_CHUNK) {
                const chunk = outputBytes.subarray(offset, Math.min(outputBytes.length, offset + MAX_CHUNK));
                const write = await this.device.transferOut(this.outEndpoint, chunk);
                if (write.status !== "ok" || write.bytesWritten !== chunk.length) {
                    throw new Error(`FTDI bulk write failed at byte ${offset}.`);
                }
                received.set(await this.readSamples(chunk.length), offset);
            }
            return received;
        }

        async close() {
            try {
                if (this.device.opened && this.interfaceNumber !== null) {
                    await this.setBitMode(0, FTDI.BITMODE_RESET);
                    await this.controlOut(FTDI.SIO_SET_LATENCY_TIMER, 16);
                    await this.device.releaseInterface(this.interfaceNumber);
                }
            } finally {
                if (this.device.opened) {
                    await this.device.close();
                }
            }
        }
    }

    class JtagTap {
        constructor(transport) {
            this.transport = transport;
            this.state = null;
        }

        makeCycle(tms, tdi) {
            let value = 0;
            if (tms) {
                value |= JTAG_PIN.TMS;
            }
            if (tdi) {
                value |= JTAG_PIN.TDI;
            }
            return [value, value | JTAG_PIN.TCK];
        }

        findPath(fromState, toState) {
            if (fromState === toState) {
                return [];
            }
            const queue = [{state: fromState, bits: []}];
            const visited = new Set([fromState]);
            while (queue.length) {
                const current = queue.shift();
                for (let tms = 0; tms <= 1; tms++) {
                    const next = TAP_NEXT[current.state][tms];
                    if (next === toState) {
                        return [...current.bits, tms];
                    }
                    if (!visited.has(next)) {
                        visited.add(next);
                        queue.push({state: next, bits: [...current.bits, tms]});
                    }
                }
            }
            throw new Error(`No TAP path from ${fromState} to ${toState}.`);
        }

        async reset() {
            const bytes = [];
            for (let i = 0; i < 6; i++) {
                bytes.push(...this.makeCycle(1, 0));
            }
            await this.transport.exchange(Uint8Array.from(bytes));
            this.state = TAP.RESET;
        }

        async goto(target) {
            const normalized = normalizeTapState(target);
            if (!this.state) {
                await this.reset();
            }
            if (normalized === TAP.RESET) {
                await this.reset();
                return;
            }
            const path = this.findPath(this.state, normalized);
            if (path.length === 0) {
                return;
            }
            const bytes = [];
            let current = this.state;
            for (const tms of path) {
                bytes.push(...this.makeCycle(tms, 0));
                current = TAP_NEXT[current][tms];
            }
            await this.transport.exchange(Uint8Array.from(bytes));
            this.state = current;
        }

        async shift(kind, bitCount, tdiHex, endState) {
            const isIr = kind === "SIR";
            const shiftState = isIr ? TAP.IRSHIFT : TAP.DRSHIFT;
            const exitState = isIr ? TAP.IREXIT1 : TAP.DREXIT1;
            const normalizedEndState = normalizeTapState(endState);
            await this.goto(shiftState);

            // FT231X synchronous bit-bang input is delayed by one output byte.
            // Keep the first post-shift JTAG cycle in this same USB exchange so
            // every shifted bit, including the last one, has a following sample.
            const endPath = this.findPath(exitState, normalizedEndState);
            if (endPath.length === 0) {
                throw new Error(`Cannot sample the final ${kind} bit while ending in ${normalizedEndState}.`);
            }

            const bytes = new Uint8Array(bitCount * 2 + 2);
            for (let bit = 0; bit < bitCount; bit++) {
                const tms = bit === bitCount - 1 ? 1 : 0;
                const tdi = getHexBit(tdiHex, bit);
                let value = 0;
                if (tms) {
                    value |= JTAG_PIN.TMS;
                }
                if (tdi) {
                    value |= JTAG_PIN.TDI;
                }
                bytes[bit * 2] = value;
                bytes[bit * 2 + 1] = value | JTAG_PIN.TCK;
            }

            const postTms = endPath[0];
            const postValue = postTms ? JTAG_PIN.TMS : 0;
            bytes[bitCount * 2] = postValue;
            bytes[bitCount * 2 + 1] = postValue | JTAG_PIN.TCK;

            const samples = await this.transport.exchange(bytes);
            const tdoBits = new Uint8Array(bitCount);
            for (let bit = 0; bit < bitCount; bit++) {
                // Match fujprog's rxpos = txpos + 2: the FT231X sample that
                // contains TDO for this rising edge arrives on the next low byte.
                tdoBits[bit] = (samples[bit * 2 + 2] & JTAG_PIN.TDO) !== 0 ? 1 : 0;
            }
            this.state = TAP_NEXT[exitState][postTms];
            await this.goto(normalizedEndState);
            return tdoBits;
        }

        async runClocks(count, runState = TAP.IDLE) {
            if (count <= 0) {
                return;
            }
            const normalized = normalizeTapState(runState);
            await this.goto(normalized);
            const tms = TAP_NEXT[normalized][0] === normalized ? 0 : 1;
            if (TAP_NEXT[normalized][tms] !== normalized) {
                throw new Error(`RUNTEST state ${normalized} cannot self-clock without leaving the state.`);
            }

            const cyclesPerChunk = 16000;
            let remaining = count;
            while (remaining > 0) {
                const cycles = Math.min(cyclesPerChunk, remaining);
                const bytes = new Uint8Array(cycles * 2);
                let value = tms ? JTAG_PIN.TMS : 0;
                for (let i = 0; i < cycles; i++) {
                    bytes[i * 2] = value;
                    bytes[i * 2 + 1] = value | JTAG_PIN.TCK;
                }
                await this.transport.exchange(bytes);
                remaining -= cycles;
            }
        }

        async readIdcode() {
            await this.reset();
            await this.goto(TAP.IDLE);
            await this.shift("SIR", 8, "E0", TAP.IRPAUSE);
            const bits = await this.shift("SDR", 32, "00000000", TAP.IDLE);
            let value = 0;
            for (let bit = 0; bit < 32; bit++) {
                if (bits[bit]) {
                    value = (value | (1 << bit)) >>> 0;
                }
            }
            return value >>> 0;
        }
    }

    class SvfExecutor {
        constructor(tap, progressCallback) {
            this.tap = tap;
            this.progressCallback = progressCallback;
            this.endDr = TAP.DRPAUSE;
            this.endIr = TAP.IRPAUSE;
        }

        compareTdo(scan, receivedBits) {
            if (!scan.tdo) {
                return;
            }
            const mask = scan.mask || "F".repeat(Math.ceil(scan.bitCount / 4));
            for (let bit = 0; bit < scan.bitCount; bit++) {
                if (!getHexBit(mask, bit)) {
                    continue;
                }
                const expected = getHexBit(scan.tdo, bit);
                if (receivedBits[bit] !== expected) {
                    const got = bitsToHex(receivedBits);
                    throw new Error(`${scan.type} TDO mismatch: got ${got}, expected ${scan.tdo}, mask ${mask}.`);
                }
            }
        }

        parseRunTest(command) {
            const tokens = command.trim().split(/\s+/);
            if (tokens.length < 2) {
                throw new Error("Malformed RUNTEST command.");
            }
            let index = 1;
            let runState = TAP.IDLE;
            if (!/^\d|^[+.\-]/.test(tokens[index])) {
                runState = normalizeTapState(tokens[index]);
                index++;
            }

            let tckCount = 0;
            let seconds = 0;
            let endState = null;
            while (index < tokens.length) {
                const token = tokens[index].toUpperCase();
                if (token === "ENDSTATE") {
                    if (index + 1 >= tokens.length) {
                        throw new Error("RUNTEST ENDSTATE is missing a TAP state.");
                    }
                    endState = normalizeTapState(tokens[index + 1]);
                    index += 2;
                    continue;
                }
                const number = Number(tokens[index]);
                const unit = (tokens[index + 1] || "").toUpperCase();
                if (!Number.isFinite(number)) {
                    throw new Error(`Unexpected RUNTEST token: ${tokens[index]}`);
                }
                if (unit === "TCK") {
                    tckCount = Math.max(tckCount, Math.floor(number));
                    index += 2;
                } else if (unit === "SEC") {
                    seconds = Math.max(seconds, number);
                    index += 2;
                } else {
                    throw new Error(`Unsupported RUNTEST unit: ${unit || "(missing)"}`);
                }
            }

            // At the 1 Mbaud FTDI setting, two synchronous bit-bang bytes make
            // one JTAG clock. Match fujprog's 500 kHz RUNTEST approximation.
            const timeClocks = Math.ceil(Math.min(seconds, 3) * 500000);
            return {runState, clocks: Math.max(1, tckCount, timeClocks), endState};
        }

        async execute(text) {
            const parsed = splitSvfCommands(text);
            let commandIndex = 0;
            for (const item of parsed.commands) {
                commandIndex++;
                const command = item.text.trim();
                const keyword = command.split(/\s+/, 1)[0].toUpperCase();
                const scan = parseScanCommand(command);

                if (scan) {
                    if (scan.smask && !/^F+$/i.test(scan.smask)) {
                        throw new Error(`${scan.type} SMASK values other than all-ones are not supported.`);
                    }
                    const endState = scan.type === "SIR" ? this.endIr : this.endDr;
                    const received = await this.tap.shift(scan.type, scan.bitCount, scan.tdi, endState);
                    this.compareTdo(scan, received);
                } else if (keyword === "STATE") {
                    const states = command.trim().split(/\s+/).slice(1);
                    if (states.length === 0) {
                        throw new Error("STATE command is missing a TAP state.");
                    }
                    for (const tapState of states) {
                        await this.tap.goto(tapState);
                    }
                } else if (keyword === "RUNTEST") {
                    const run = this.parseRunTest(command);
                    await this.tap.runClocks(run.clocks, run.runState);
                    if (run.endState) {
                        await this.tap.goto(run.endState);
                    }
                } else if (keyword === "ENDDR") {
                    const [, tapState] = command.trim().split(/\s+/, 2);
                    this.endDr = normalizeTapState(tapState);
                    if (![TAP.DRPAUSE, TAP.IDLE].includes(this.endDr)) {
                        throw new Error(`Unsupported ENDDR state ${tapState}; expected DRPAUSE or IDLE.`);
                    }
                } else if (keyword === "ENDIR") {
                    const [, tapState] = command.trim().split(/\s+/, 2);
                    this.endIr = normalizeTapState(tapState);
                    if (![TAP.IRPAUSE, TAP.IDLE].includes(this.endIr)) {
                        throw new Error(`Unsupported ENDIR state ${tapState}; expected IRPAUSE or IDLE.`);
                    }
                } else if (["HDR", "HIR", "TDR", "TIR"].includes(keyword)) {
                    const match = command.match(/^\s*(?:HDR|HIR|TDR|TIR)\s+(\d+)\s*$/i);
                    if (!match || Number.parseInt(match[1], 10) !== 0) {
                        throw new Error(`${keyword} is supported only with a zero-bit header/trailer.`);
                    }
                } else if (keyword === "FREQUENCY") {
                    // The FT231X synchronous bit-bang clock is fixed by the
                    // configured baud rate, so the SVF frequency hint is ignored.
                } else if (keyword === "TRST") {
                    const value = command.trim().split(/\s+/)[1]?.toUpperCase();
                    if (value !== "OFF" && value !== "Z" && value !== "ABSENT") {
                        throw new Error(`Unsupported TRST mode: ${value || "(missing)"}`);
                    }
                } else {
                    throw new Error(`Unsupported SVF command: ${keyword}`);
                }

                this.progressCallback?.({
                    commandIndex,
                    commandCount: parsed.commands.length,
                    percent: item.endOffset * 100 / parsed.totalLength,
                    keyword
                });

                if ((commandIndex & 31) === 0) {
                    await new Promise((resolve) => setTimeout(resolve, 0));
                }
            }

            return {commandCount: parsed.commands.length};
        }
    }

    async function chooseDevice() {
        if (!webUsbSupported) {
            throw new Error("WebUSB is not available in this browser.");
        }
        return navigator.usb.requestDevice({
            filters: [{vendorId: FTDI_VENDOR_ID, productId: ULX3S_FT231X_PRODUCT_ID}]
        });
    }

    async function connectFlasher() {
        if (state.busy) {
            return;
        }
        setBusy(true);
        setProgress(0, "Connecting...");
        try {
            if (state.transport) {
                await disconnectFlasher();
            }
            const device = await chooseDevice();
            if (device.vendorId !== FTDI_VENDOR_ID || device.productId !== ULX3S_FT231X_PRODUCT_ID) {
                throw new Error("The selected USB device is not the ULX3S FT231X interface.");
            }
            const transport = new FtdiWebUsbTransport(device);
            await transport.open();
            state.transport = transport;
            state.tap = new JtagTap(transport);
            clearIdcode();
            const product = device.productName || "ULX3S FT231X";
            const serial = device.serialNumber ? `, S/N ${device.serialNumber}` : "";
            els.deviceStatus.textContent = `${product}${serial}`;
            appendLog(`Connected to ${product}${serial}.`);
            setProgress(0, "Connected - probe JTAG or program SVF");
        } catch (error) {
            if (error.name !== "NotFoundError") {
                appendLog(error.message, "error");
                const driverHintShown = appendWindowsDriverHint(error);
                setProgress(0, driverHintShown ? "Connection failed - WinUSB required" : "Connection failed");
            } else {
                setProgress(0, "Device selection cancelled");
            }
        } finally {
            setBusy(false);
        }
    }

    async function disconnectFlasher() {
        if (!state.transport) {
            return;
        }
        const transport = state.transport;
        state.transport = null;
        state.tap = null;
        try {
            await transport.close();
            appendLog("USB JTAG interface disconnected.");
        } catch (error) {
            appendLog(`Disconnect cleanup: ${error.message}`, "error");
        }
        els.deviceStatus.textContent = "Not connected";
        clearIdcode();
        setProgress(0, "Idle");
        setBusy(false);
    }

    async function probeJtag() {
        if (!state.tap || state.busy) {
            return;
        }
        setBusy(true);
        setProgress(5, "Resetting JTAG TAP...");
        try {
            const idcode = await state.tap.readIdcode();
            state.idcode = idcode;
            state.idName = ECP5_IDCODES.get(idcode) || "Unknown JTAG device";
            els.idcode.textContent = `${formatIdcode(idcode)} - ${state.idName}`;
            const recognized = ECP5_IDCODES.has(idcode);
            els.idcode.classList.toggle("ok", recognized);
            els.idcode.classList.toggle("error", !recognized);
            if (!recognized) {
                throw new Error(`JTAG ID ${formatIdcode(idcode)} is not a recognized ULX3S ECP5 device.`);
            }
            appendLog(`JTAG probe found ${state.idName} (${formatIdcode(idcode)}).`, "ok");
            setProgress(0, "JTAG probe passed");
        } catch (error) {
            appendLog(error.message, "error");
            setProgress(0, "JTAG probe failed");
        } finally {
            setBusy(false);
        }
    }

    async function loadProgrammingFile(file) {
        state.file = null;
        state.svfText = "";
        els.fileName.textContent = "No FPGA image selected";
        els.fileDetails.textContent = "";
        setBusy(state.busy);
        if (!file) {
            return;
        }

        const lowerName = file.name.toLowerCase();
        const isBit = lowerName.endsWith(".bit");
        const isSvf = lowerName.endsWith(".svf");
        if (!isBit && !isSvf) {
            appendLog("Select a .bit or .svf file built for the target ULX3S FPGA.", "error");
            els.fileInput.value = "";
            return;
        }
        if (file.size > 64 * 1024 * 1024) {
            appendLog("FPGA image is larger than the 64 MiB browser safety limit.", "error");
            els.fileInput.value = "";
            return;
        }

        try {
            let text;
            let conversionNote = "";
            if (isBit) {
                const bytes = new Uint8Array(await file.arrayBuffer());
                const converted = bitstreamToSvf(bytes);
                text = converted.svfText;
                const target = ECP5_IDCODES.get(converted.idcode);
                conversionNote = `, ${target} ${formatIdcode(converted.idcode)}`;
                appendLog(`Converted ${file.name} to the Project Trellis ECP5 SRAM SVF sequence for ${target}.`);
            } else {
                text = await file.text();
            }

            const parsed = splitSvfCommands(text);
            if (parsed.commands.length === 0) {
                throw new Error("The selected FPGA image contains no programming commands.");
            }
            state.file = file;
            state.svfText = text;
            els.fileName.textContent = file.name;
            els.fileDetails.textContent = `${(file.size / 1024).toFixed(1)} KiB${conversionNote}, ${parsed.commands.length.toLocaleString()} SVF commands`;
            appendLog(`Loaded ${file.name}: ${parsed.commands.length.toLocaleString()} programming commands.`);
        } catch (error) {
            appendLog(`Could not load FPGA image: ${error.message}`, "error");
            els.fileInput.value = "";
        }
        setBusy(false);
    }

    function svfExpectedIdcode(text) {
        const {commands} = splitSvfCommands(text);
        for (const item of commands) {
            const scan = parseScanCommand(item.text);
            if (scan?.type === "SDR" && scan.bitCount === 32 && scan.tdo && (scan.mask || "FFFFFFFF") === "FFFFFFFF") {
                const value = Number.parseInt(scan.tdo, 16) >>> 0;
                if (ECP5_IDCODES.has(value)) {
                    return value;
                }
            }
        }
        return null;
    }

    async function programSvf() {
        if (!state.tap || !state.svfText || state.busy) {
            return;
        }
        setBusy(true);
        setProgress(1, "Checking target...");
        const started = performance.now();
        try {
            const actualId = await state.tap.readIdcode();
            const actualName = ECP5_IDCODES.get(actualId);
            if (!actualName) {
                throw new Error(`Refusing to program unrecognized JTAG ID ${formatIdcode(actualId)}.`);
            }
            state.idcode = actualId;
            state.idName = actualName;
            els.idcode.textContent = `${formatIdcode(actualId)} - ${actualName}`;
            els.idcode.classList.add("ok");
            els.idcode.classList.remove("error");

            const expectedId = svfExpectedIdcode(state.svfText);
            if (expectedId !== null && expectedId !== actualId) {
                const expectedName = ECP5_IDCODES.get(expectedId) || "unknown ECP5";
                throw new Error(`FPGA image target mismatch: board is ${actualName} (${formatIdcode(actualId)}), image expects ${expectedName} (${formatIdcode(expectedId)}).`);
            }

            appendLog(`Programming ${state.file.name} into ${actualName} FPGA SRAM...`);
            const executor = new SvfExecutor(state.tap, ({commandIndex, commandCount, percent, keyword}) => {
                setProgress(percent, `${Math.floor(percent)}% - ${keyword} ${commandIndex.toLocaleString()}/${commandCount.toLocaleString()}`);
            });
            const result = await executor.execute(state.svfText);

            const elapsed = (performance.now() - started) / 1000;
            setProgress(100, `Programming complete in ${elapsed.toFixed(1)} s`);
            appendLog(`Programming stream completed successfully in ${elapsed.toFixed(1)} s (${result.commandCount.toLocaleString()} commands).`, "ok");
        } catch (error) {
            appendLog(`Programming stopped: ${error.message}`, "error");
            setProgress(0, "Programming failed");
            try {
                await state.tap.reset();
                await state.tap.goto(TAP.IDLE);
            } catch {
                // The USB/JTAG connection may already be gone; preserve the original error.
            }
        } finally {
            setBusy(false);
        }
    }

    function initialize() {
        clearIdcode();
        setProgress(0, "Idle");
        if (!webUsbSupported) {
            els.unsupported.classList.remove("hidden");
            els.connectButton.disabled = true;
            appendLog("WebUSB is unavailable. Use current Chrome/Edge over HTTPS or localhost.", "error");
        }

        els.fileInput.addEventListener("change", () => {
            void loadProgrammingFile(els.fileInput.files?.[0] || null);
        });
        els.connectButton.addEventListener("click", () => void connectFlasher());
        els.disconnectButton.addEventListener("click", () => void disconnectFlasher());
        els.probeButton.addEventListener("click", () => void probeJtag());
        els.programButton.addEventListener("click", () => void programSvf());
        els.copyLogButton.addEventListener("click", () => void copyFlasherLog());
        els.clearLogButton.addEventListener("click", clearFlasherLog);

        if (webUsbSupported) {
            navigator.usb.addEventListener("disconnect", (event) => {
                if (state.transport?.device === event.device) {
                    state.transport = null;
                    state.tap = null;
                    els.deviceStatus.textContent = "Disconnected by operating system";
                    clearIdcode();
                    setProgress(0, "Disconnected");
                    appendLog("ULX3S USB interface disconnected by the operating system.", "error");
                    setBusy(false);
                }
            });
        }
        setBusy(false);
    }

    initialize();
})();
