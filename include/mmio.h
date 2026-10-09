#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

/* BCM2711 (Raspberry Pi 4) low peripheral mode base address */
#define PERIPHERAL_BASE   0xFE000000UL
#define GPIO_BASE         (PERIPHERAL_BASE + 0x200000UL)
#define UART0_BASE        (PERIPHERAL_BASE + 0x201000UL)

static inline void mmio_write(uint64_t reg, uint32_t val)
{
    *(volatile uint32_t *)reg = val;
}

static inline uint32_t mmio_read(uint64_t reg)
{
    return *(volatile uint32_t *)reg;
}

#endif /* MMIO_H */
