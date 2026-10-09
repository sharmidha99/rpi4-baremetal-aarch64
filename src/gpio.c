#include "gpio.h"
#include "mmio.h"

/* GPIO function select registers: 3 bits per pin, 10 pins per register */
#define GPFSEL(n)   (GPIO_BASE + 0x00 + ((n) * 4))
/* Output set/clear registers: 1 bit per pin, 32 pins per register */
#define GPSET(n)    (GPIO_BASE + 0x1C + ((n) * 4))
#define GPCLR(n)    (GPIO_BASE + 0x28 + ((n) * 4))

void gpio_set_output(unsigned int pin)
{
    unsigned int reg_index = pin / 10;
    unsigned int shift = (pin % 10) * 3;

    uint32_t val = mmio_read(GPFSEL(reg_index));
    val &= ~(7u << shift);   /* clear existing function bits */
    val |= (1u << shift);    /* 001 = output */
    mmio_write(GPFSEL(reg_index), val);
}

void gpio_set(unsigned int pin)
{
    unsigned int reg_index = pin / 32;
    unsigned int shift = pin % 32;
    mmio_write(GPSET(reg_index), 1u << shift);
}

void gpio_clear(unsigned int pin)
{
    unsigned int reg_index = pin / 32;
    unsigned int shift = pin % 32;
    mmio_write(GPCLR(reg_index), 1u << shift);
}
