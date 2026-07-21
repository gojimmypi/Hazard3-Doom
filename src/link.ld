ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    .vectors 0x00000040 :
    {
        KEEP(*(.vectors))
    } > RAM

    .text :
    {
        *(.text*)
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss :
    {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(16);
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /*
     * The upper 64 KiB of the physical 128 KiB SRAM is a dedicated Doom
     * 320x200 indexed working screen. Keeping the renderer target out of the
     * unified SDRAM cache leaves that cache available for code, WAD and heap.
     */
    __doom_screenbuffer_base = 0x00010000;
    __doom_screenbuffer_end = __doom_screenbuffer_base + 320 * 200;

    ASSERT(__bss_end <= __stack_top - 16K,
        "Monitor image leaves less than 16 KiB for the Doom/interrupt stack")
    ASSERT(__doom_screenbuffer_end <= 0x00020000,
        "Doom screen buffer exceeds internal SRAM")
}
