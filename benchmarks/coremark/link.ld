ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 128K
}

PHDRS
{
    text PT_LOAD FLAGS(5); /* R + X */
    data PT_LOAD FLAGS(6); /* R + W */
}

SECTIONS
{
    .vectors 0x00000040 :
    {
        KEEP(*(.vectors))
    } > RAM :text

    .text :
    {
        *(.text*)
        *(.rodata*)
        *(.coremark_diag.text*)
    } > RAM :text

    .data :
    {
        . = ALIGN(4);
        *(.data*)
        *(.sdata*)
    } > RAM :data

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM :data

    . = ALIGN(16);
    __image_end = .;
    __ram_origin = ORIGIN(RAM);
    __ram_length = LENGTH(RAM);
    __ram_end = ORIGIN(RAM) + LENGTH(RAM);
    __stack_top = __ram_end;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
    }
}

ASSERT(__image_end <= (__stack_top - 0x4000),
       "CoreMark image leaves less than 16 KiB for stack")
