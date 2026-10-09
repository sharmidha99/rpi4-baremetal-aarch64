#include "uart.h"
#include "mmio.h"

#define GPFSEL1     (GPIO_BASE + 0x04)
#define GPPUPPDN0   (GPIO_BASE + 0xE4)  /* BCM2711 pull-up/down control */

#define UART0_DR    (UART0_BASE + 0x00)
#define UART0_FR    (UART0_BASE + 0x18)
#define UART0_IBRD  (UART0_BASE + 0x24)
#define UART0_FBRD  (UART0_BASE + 0x28)
#define UART0_LCRH  (UART0_BASE + 0x2C)
#define UART0_CR    (UART0_BASE + 0x30)
#define UART0_IMSC  (UART0_BASE + 0x38)
#define UART0_ICR   (UART0_BASE + 0x44)

static void delay(volatile int32_t count)
{
    while (count--) {
        asm volatile("nop");
    }
}

void uart_init(void)
{
    /* Disable UART0 while configuring it */
    mmio_write(UART0_CR, 0x00000000);

    /* GPIO14/15 -> ALT0 (TXD0/RXD0) */
    uint32_t sel = mmio_read(GPFSEL1);
    sel &= ~((7u << 12) | (7u << 15));
    sel |= (4u << 12) | (4u << 15);
    mmio_write(GPFSEL1, sel);

    /* Disable pull-up/down on GPIO14/15 (BCM2711 scheme) */
    uint32_t pud = mmio_read(GPPUPPDN0);
    pud &= ~((3u << 28) | (3u << 30));
    mmio_write(GPPUPPDN0, pud);

    mmio_write(UART0_ICR, 0x7FF);   /* clear pending interrupts */

    /* 115200 baud @ 48MHz UART clock */
    mmio_write(UART0_IBRD, 26);
    mmio_write(UART0_FBRD, 3);

    mmio_write(UART0_LCRH, (1 << 4) | (3 << 5)); /* FIFO enable, 8N1 */
    mmio_write(UART0_IMSC, 0x7FF);               /* mask all interrupts */
    mmio_write(UART0_CR, (1 << 0) | (1 << 8) | (1 << 9)); /* enable UART, TX, RX */

    delay(150);
}

void uart_putc(unsigned char c)
{
    while (mmio_read(UART0_FR) & (1 << 5)) {
        /* wait while TX FIFO full */
    }
    mmio_write(UART0_DR, c);
}

unsigned char uart_getc(void)
{
    while (mmio_read(UART0_FR) & (1 << 4)) {
        /* wait while RX FIFO empty */
    }
    return (unsigned char)mmio_read(UART0_DR);
}

void uart_puts(const char *str)
{
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc((unsigned char)*str);
        str++;
    }
}
