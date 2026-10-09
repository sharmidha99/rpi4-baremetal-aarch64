#include <stdint.h>
#include "uart.h"
#include "gpio.h"

#define ACT_LED_PIN 42

static void delay(volatile uint64_t count)
{
    while (count--) {
        asm volatile("nop");
    }
}

void main(void)
{
    uart_init();
    uart_puts("Hello from bare-metal Raspberry Pi 4 (AArch64)!\n");

    uart_puts("Testing exception vector table with a supervisor call (SVC)...\n");
    asm volatile("svc #0");
    uart_puts("Back from the exception handler - vectors are working!\n");

    uart_puts("Blinking the ACT LED as a heartbeat.\n");

    gpio_set_output(ACT_LED_PIN);

    while (1) {
        gpio_set(ACT_LED_PIN);
        delay(15000000);
        gpio_clear(ACT_LED_PIN);
        delay(15000000);
    }
}
