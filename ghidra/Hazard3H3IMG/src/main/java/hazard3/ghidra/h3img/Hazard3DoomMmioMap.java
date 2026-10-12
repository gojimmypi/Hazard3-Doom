package hazard3.ghidra.h3img;

/**
 * Hazard3-Doom APB/MMIO definitions used by the Ghidra analyzer.
 *
 * <p>This map is intentionally separate from the H3IMG container loader. H3IMG
 * itself is board-neutral and carries only application load metadata; these
 * definitions describe the current Hazard3-Doom SoC peripheral map.</p>
 */
final class Hazard3DoomMmioMap {
    static final class Peripheral {
        final String blockName;
        final long base;
        final long size;
        final String comment;
        final Register[] registers;

        Peripheral(String blockName, long base, long size, String comment,
                Register... registers) {
            this.blockName = blockName;
            this.base = base;
            this.size = size;
            this.comment = comment;
            this.registers = registers;
        }
    }

    static final class Register {
        final long offset;
        final String name;
        final String comment;

        Register(long offset, String name, String comment) {
            this.offset = offset;
            this.name = name;
            this.comment = comment;
        }
    }

    private static Register reg(long offset, String name, String comment) {
        return new Register(offset, name, comment);
    }

    static final Peripheral[] PERIPHERALS = {
        new Peripheral(
            "APB_TIMER",
            0x4000_0000L,
            0x0000_4000L,
            "Hazard3 system timer APB window",
            reg(0x00, "TIMER_CTRL", "Timer control; bit 0 enables the timer"),
            reg(0x08, "TIMER_MTIME", "Machine timer counter, low 32 bits"),
            reg(0x0c, "TIMER_MTIMEH", "Machine timer counter, high 32 bits"),
            reg(0x10, "TIMER_MTIMECMP", "Machine timer compare, low 32 bits"),
            reg(0x14, "TIMER_MTIMECMPH", "Machine timer compare, high 32 bits")
        ),
        new Peripheral(
            "APB_UART",
            0x4000_4000L,
            0x0000_4000L,
            "Hazard3 UART APB window",
            reg(0x00, "UART_CSR", "UART control/status; bit 0 enables the UART"),
            reg(0x04, "UART_DIV", "UART baud-rate divider"),
            reg(0x08, "UART_FSTAT", "UART FIFO status"),
            reg(0x0c, "UART_TX", "UART transmit data"),
            reg(0x10, "UART_RX", "UART receive data")
        ),
        new Peripheral(
            "APB_GPIO",
            0x4000_8000L,
            0x0000_1000L,
            "Hazard3 GPIO APB window",
            reg(0x00, "GPIO_OUT", "Board LED GPIO output register")
        ),
        new Peripheral(
            "APB_SAO",
            0x4000_9000L,
            0x0000_1000L,
            "Hazard3 SAO/I2C/GPIO APB window",
            reg(0x00, "SAO_COMMAND", "SAO I2C command register"),
            reg(0x04, "SAO_STATUS", "SAO I2C/GPIO/ownership status"),
            reg(0x08, "SAO_TXDATA", "SAO I2C transmit byte"),
            reg(0x0c, "SAO_RXDATA", "SAO I2C receive byte"),
            reg(0x10, "SAO_CLKDIV", "SAO I2C clock divider"),
            reg(0x14, "SAO_TIMEOUT", "SAO I2C timeout in system-clock cycles"),
            reg(0x18, "SAO_GPIO", "SAO GPIO output/output-enable control and inputs"),
            reg(0x1c, "SAO_LINES", "SAO SDA/SCL/GPIO sampled line state"),
            reg(0x20, "SAO_ID", "SAO bridge ID; current value is ASCII SAO1"),
            reg(0x24, "SAO_VERSION", "SAO bridge version register"),
            reg(0x28, "SAO_OWNER", "SAO shared-controller ownership/request state")
        ),
        new Peripheral(
            "APB_SD",
            0x4000_a000L,
            0x0000_1000L,
            "Hazard3 micro-SD SPI/arbitration APB window",
            reg(0x00, "SD_CTRL", "SD SPI control; bit 0 is CS_n (1 = deselected)"),
            reg(0x04, "SD_CLKDIV", "SD SPI half-period divider"),
            reg(0x08, "SD_DATA", "SD SPI data; write starts transfer, read returns byte"),
            reg(0x0c, "SD_STATUS", "SD SPI/arbitration status"),
            reg(0x10, "SD_OWNER", "SD ownership request; bit 0 requests FPGA ownership")
        ),
        new Peripheral(
            "APB_VIDEO",
            0x4000_c000L,
            0x0000_4000L,
            "Hazard3 HDMI/video APB window",
            reg(0x00, "HAZARD3_VIDEO_STATUS", "Video status register"),
            reg(0x04, "HAZARD3_VIDEO_CONTROL", "Video control/present register"),
            reg(0x08, "HAZARD3_VIDEO_PALETTE_INDEX", "Indexed-video palette address"),
            reg(0x0c, "HAZARD3_VIDEO_PALETTE_DATA", "Indexed-video palette data"),
            reg(0x10, "HAZARD3_VIDEO_FRAME_COUNT", "Completed frame count"),
            reg(0x14, "HAZARD3_VIDEO_DMA_CYCLES", "Last/observed video DMA cycle count"),
            reg(0x18, "HAZARD3_VIDEO_PRESENT_COUNT", "Video present count"),
            reg(0x1c, "HAZARD3_VIDEO_FPGA_BUILD_ID", "FPGA video-system build ID"),
            reg(0x20, "HAZARD3_VIDEO_DDR_STATUS", "External-memory/video-path status"),
            reg(0x24, "HAZARD3_VIDEO_DDR_CORE_BUILD_ID", "External-memory core build ID"),
            reg(0x28, "HAZARD3_VIDEO_DDR_ADAPTER_BUILD_ID", "External-memory adapter build ID"),
            reg(0x2c, "HAZARD3_VIDEO_DIRECT_ADDRESS", "Direct block-RAM access address"),
            reg(0x30, "HAZARD3_VIDEO_DIRECT_DATA", "Direct block-RAM access data")
        )
    };

    private Hazard3DoomMmioMap() {
    }
}
