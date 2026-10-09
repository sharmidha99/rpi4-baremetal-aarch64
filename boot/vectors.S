/*
 * AArch64 exception vector table.
 *
 * The table has 16 entries, grouped into 4 sets of 4 (sync/IRQ/FIQ/SError):
 *   1) Current EL, using SP_EL0        (not used by us - we run on SP_EL1)
 *   2) Current EL, using SP_ELx        (this is the set we actually use)
 *   3) Lower EL, exception from AArch64 (not used - we never drop to EL0)
 *   4) Lower EL, exception from AArch32 (not used - AArch32 not involved)
 *
 * Each entry is exactly 0x80 (128) bytes, and the table itself must be
 * aligned to 0x800 (2KB) - this is an architectural requirement of VBAR_ELx.
 */

.section ".text.vectors", "ax"
.align 11
.global vectors
vectors:
    .align 7
    b   sync_invalid_el1t
    .align 7
    b   irq_invalid_el1t
    .align 7
    b   fiq_invalid_el1t
    .align 7
    b   serror_invalid_el1t

    .align 7
    b   sync_el1h
    .align 7
    b   irq_el1h
    .align 7
    b   fiq_el1h
    .align 7
    b   serror_el1h

    .align 7
    b   sync_invalid_el0_64
    .align 7
    b   irq_invalid_el0_64
    .align 7
    b   fiq_invalid_el0_64
    .align 7
    b   serror_invalid_el0_64

    .align 7
    b   sync_invalid_el0_32
    .align 7
    b   irq_invalid_el0_32
    .align 7
    b   fiq_invalid_el0_32
    .align 7
    b   serror_invalid_el0_32

/*
 * Common entry/exit sequence: save all general purpose registers, call the
 * C handler with (type, ESR_EL1, ELR_EL1, FAR_EL1), restore, and return with
 * ERET (which resumes execution at ELR_EL1 in the saved PSTATE).
 */
.macro handler_entry type
    sub     sp, sp, #256
    stp     x0,  x1,  [sp, #16*0]
    stp     x2,  x3,  [sp, #16*1]
    stp     x4,  x5,  [sp, #16*2]
    stp     x6,  x7,  [sp, #16*3]
    stp     x8,  x9,  [sp, #16*4]
    stp     x10, x11, [sp, #16*5]
    stp     x12, x13, [sp, #16*6]
    stp     x14, x15, [sp, #16*7]
    stp     x16, x17, [sp, #16*8]
    stp     x18, x19, [sp, #16*9]
    stp     x20, x21, [sp, #16*10]
    stp     x22, x23, [sp, #16*11]
    stp     x24, x25, [sp, #16*12]
    stp     x26, x27, [sp, #16*13]
    stp     x28, x29, [sp, #16*14]
    str     x30,      [sp, #16*15]

    mov     x0, #\type
    mrs     x1, esr_el1
    mrs     x2, elr_el1
    mrs     x3, far_el1
    bl      exception_handler

    ldp     x0,  x1,  [sp, #16*0]
    ldp     x2,  x3,  [sp, #16*1]
    ldp     x4,  x5,  [sp, #16*2]
    ldp     x6,  x7,  [sp, #16*3]
    ldp     x8,  x9,  [sp, #16*4]
    ldp     x10, x11, [sp, #16*5]
    ldp     x12, x13, [sp, #16*6]
    ldp     x14, x15, [sp, #16*7]
    ldp     x16, x17, [sp, #16*8]
    ldp     x18, x19, [sp, #16*9]
    ldp     x20, x21, [sp, #16*10]
    ldp     x22, x23, [sp, #16*11]
    ldp     x24, x25, [sp, #16*12]
    ldp     x26, x27, [sp, #16*13]
    ldp     x28, x29, [sp, #16*14]
    ldr     x30,      [sp, #16*15]
    add     sp, sp, #256
    eret
.endm

sync_invalid_el1t:
    handler_entry 0
irq_invalid_el1t:
    handler_entry 1
fiq_invalid_el1t:
    handler_entry 2
serror_invalid_el1t:
    handler_entry 3

sync_el1h:
    handler_entry 4
irq_el1h:
    handler_entry 5
fiq_el1h:
    handler_entry 6
serror_el1h:
    handler_entry 7

sync_invalid_el0_64:
    handler_entry 8
irq_invalid_el0_64:
    handler_entry 9
fiq_invalid_el0_64:
    handler_entry 10
serror_invalid_el0_64:
    handler_entry 11

sync_invalid_el0_32:
    handler_entry 12
irq_invalid_el0_32:
    handler_entry 13
fiq_invalid_el0_32:
    handler_entry 14
serror_invalid_el0_32:
    handler_entry 15
