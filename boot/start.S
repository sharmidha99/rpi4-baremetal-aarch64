.section ".text.boot"
.global _start

_start:
    /* Only let core 0 continue; park cores 1-3 */
    mrs     x1, mpidr_el1
    and     x1, x1, #3
    cbnz    x1, hang

    /* Zero the .bss section */
    ldr     x1, =__bss_start
    ldr     x2, =__bss_end
    sub     x2, x2, x1
    cbz     x2, 2f
1:
    str     xzr, [x1], #8
    subs    x2, x2, #8
    b.gt    1b
2:
    /* Set up the stack just below the kernel load address */
    ldr     x1, =_start
    mov     sp, x1

    /* The firmware typically leaves us at EL2; drop to EL1 so that
       VBAR_EL1 (and later the timer/GIC/MMU) all operate at a single,
       consistent exception level. */
    bl      switch_to_el1

    /* Install our exception vector table */
    ldr     x1, =vectors
    msr     vbar_el1, x1

    bl      main

hang:
    wfe
    b       hang

/* ---------------------------------------------------------------- */
/* Drop from EL2 to EL1. If already at EL1 (or below), just return. */
.global switch_to_el1
switch_to_el1:
    mrs     x0, CurrentEL
    lsr     x0, x0, #2
    cmp     x0, #2
    b.ne    1f

    /* EL1 will execute in AArch64 */
    mov     x0, #(1 << 31)
    msr     hcr_el2, x0

    /* Target EL1h (SP_EL1), all exceptions masked until we set up
       the timer/GIC in a later step */
    mov     x0, #0x3c5
    msr     spsr_el2, x0

    adr     x0, 1f
    msr     elr_el2, x0
    eret
1:
    ret
