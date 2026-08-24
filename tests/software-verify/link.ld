OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    /*
     * Match the ULX3S-12F monitor execution path: code is loaded into the
     * cached external SDRAM window. Keep clear of the 0x20040000 framebuffer.
     */
    . = 0x20000040;

    .text :
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    }

    . = ALIGN(4);
    .data :
    {
        *(.sdata*)
        *(.data*)
    }

    . = ALIGN(4);
    __bss_start = .;
    .bss :
    {
        *(.sbss*)
        *(.bss*)
        *(COMMON)
    }
    __bss_end = .;

    ASSERT(. < 0x20030000, "software verifier image overlaps reserved stack area")

    __stack_top = 0x2003fff0;
}
