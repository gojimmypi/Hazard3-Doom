OUTPUT_ARCH(riscv)
ENTRY(_doom_start)

MEMORY
{
    DOOM_IMAGE (rwx) : ORIGIN = 0x20100000, LENGTH = 3M
}

SECTIONS
{
    . = ORIGIN(DOOM_IMAGE);
    .text :
    {
        KEEP(*(.text.doom_entry))
        KEEP(*(.init))
        KEEP(*(.fini))
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
    } > DOOM_IMAGE
    . = ALIGN(16);
    .data :
    {
        __doom_data_start = .;
        *(.data)
        *(.data.*)
        *(.gnu.linkonce.d.*)
        *(.got)
        *(.got.*)
        . = ALIGN(16);
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        __preinit_array_start = .;
        KEEP(*(.preinit_array))
        __preinit_array_end = .;
        __init_array_start = .;
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*)))
        KEEP(*(.init_array))
        __init_array_end = .;
        __fini_array_start = .;
        KEEP(*(SORT_BY_INIT_PRIORITY(.fini_array.*)))
        KEEP(*(.fini_array))
        __fini_array_end = .;
        KEEP(*(.ctors))
        KEEP(*(.dtors))
        __doom_data_end = .;
    } > DOOM_IMAGE
    .bss ALIGN(16) (NOLOAD) :
    {
        /* The packaged payload is padded through this aligned address. */
        __doom_image_load_end = .;
        __doom_bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.gnu.linkonce.b.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(16);
        __doom_bss_end = .;
    } > DOOM_IMAGE
    __doom_image_end = .;
    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
    ASSERT(__doom_image_end <= ORIGIN(DOOM_IMAGE) + LENGTH(DOOM_IMAGE),
        "Doom image exceeds its 3 MiB SDRAM reservation")
}
