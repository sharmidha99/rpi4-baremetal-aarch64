ENTRY(_start)

SECTIONS
{
    /* AArch64 kernel8.img is loaded here by the Pi 4 firmware */
    . = 0x80000;

    .text : {
        KEEP(*(.text.boot))
        . = ALIGN(0x800);
        KEEP(*(.text.vectors))
        *(.text .text.*)
    }

    .rodata : {
        *(.rodata .rodata.*)
    }

    .data : {
        *(.data .data.*)
    }

    . = ALIGN(16);
    __bss_start = .;
    .bss : {
        *(.bss .bss.*)
        *(COMMON)
    }
    __bss_end = .;
}
