ENTRY(_start)

MEMORY
{
    /*
     * The compact 12F monitor is loaded by GDB after FPGA configuration.
     * Keep the first 256 KiB uncached so debugger writes cannot leave stale
     * cache lines. The Doom working screen begins immediately afterward.
     */
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

SECTIONS
{
    .vectors 0x20000040 :
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

    __doom_screenbuffer_base = 0x20040000;
    __doom_screenbuffer_end = __doom_screenbuffer_base + 320 * 200;

    ASSERT(__bss_end <= __stack_top - 16K,
        "12F monitor image leaves less than 16 KiB for the monitor stack")
    ASSERT(__doom_screenbuffer_end <= 0x20050000,
        "12F Doom screen buffer exceeds its reserved 64 KiB SDRAM region")
}
