#include "exceptions.h"
#include "uart.h"

static const char *exception_names[16] = {
    "Synchronous (SP0, unexpected)",
    "IRQ (SP0, unexpected)",
    "FIQ (SP0, unexpected)",
    "SError (SP0, unexpected)",
    "Synchronous (EL1h)",
    "IRQ (EL1h)",
    "FIQ (EL1h)",
    "SError (EL1h)",
    "Synchronous (lower EL, AArch64, unexpected)",
    "IRQ (lower EL, AArch64, unexpected)",
    "FIQ (lower EL, AArch64, unexpected)",
    "SError (lower EL, AArch64, unexpected)",
    "Synchronous (lower EL, AArch32, unexpected)",
    "IRQ (lower EL, AArch32, unexpected)",
    "FIQ (lower EL, AArch32, unexpected)",
    "SError (lower EL, AArch32, unexpected)",
};

static void print_hex64(uint64_t val)
{
    char buf[19];
    buf[0] = '0';
    buf[1] = 'x';
    buf[18] = '\0';
    for (int i = 0; i < 16; i++) {
        uint8_t nibble = (uint8_t)((val >> ((15 - i) * 4)) & 0xF);
        buf[2 + i] = (nibble < 10) ? (char)('0' + nibble) : (char)('a' + nibble - 10);
    }
    uart_puts(buf);
}

void exception_handler(uint64_t type, uint64_t esr, uint64_t elr, uint64_t far)
{
    uart_puts("\n[EXCEPTION] ");
    uart_puts(exception_names[type]);
    uart_puts("\n  ESR_EL1 = ");
    print_hex64(esr);
    uart_puts("\n  ELR_EL1 = ");
    print_hex64(elr);
    uart_puts("\n  FAR_EL1 = ");
    print_hex64(far);
    uart_puts("\n");
}
