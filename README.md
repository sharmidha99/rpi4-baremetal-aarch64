# rpi4-baremetal-aarch64

> Bare-metal **AArch64 / ARM64** programming on the **Raspberry Pi 4** (**BCM2711**): PL011 UART, GPIO, exception vector table, custom linker script and boot stub — a clean starting point for OS dev and your own RTOS.

A minimal, well-commented bare-metal kernel for the Raspberry Pi 4. It boots
straight into `main()`, brings up the PL011 UART for a serial console, installs
an exception vector table (tested with an `SVC`), and blinks the ACT LED as a
heartbeat. No operating system, no libc — just you and the hardware.

Great for learning: embedded systems, ARMv8-A, bare-metal boot, cross-compiling,
interrupts/exceptions, and memory-mapped I/O (MMIO).

> 📖 New to the code? Read **[ARCHITECTURE.md](ARCHITECTURE.md)** for a full
> boot-to-blink walkthrough of how control flows and what every file does.

## Features

- Boots as `kernel8.img` at `0x80000` (AArch64 load address)
- Reset entry stub: parks secondary cores, zeroes `.bss`, sets up the stack
- PL011 **UART** driver (init / putc / getc / puts) — 115200 8N1 serial console
- **GPIO** driver (set output / set / clear) driving the ACT LED
- **Exception vector table** (`VBAR_EL1`) with a working `SVC` handler
- Custom `linker.ld` and `Makefile` using the `aarch64-linux-gnu` cross toolchain

## Toolchain (WSL2 / Linux)

```bash
sudo apt update
sudo apt install gcc-aarch64-linux-gnu make
```

## Build

```bash
make
```

Produces `kernel8.img` in the project root.

## SD card layout

Format the SD card as FAT32 and copy onto it:

1. The Raspberry Pi 4 firmware boot files (get these once from
   https://github.com/raspberrypi/firmware/tree/master/boot — you only need
   `bootcode.bin`, `start4.elf`, `fixup4.dat`, `start4cd.elf`, `fixup4cd.dat`).
2. This project's `config.txt`.
3. This project's `kernel8.img` (overwrite after every rebuild).

## Wiring for the serial console

The Pi 4 has no exposed USB-serial console by default, so wire a
USB-to-TTL (**3.3V!**) serial adapter to the GPIO header:

| Adapter | Pi 4 GPIO header |
|---|---|
| GND | Pin 6 (GND) |
| RXD | Pin 8 (GPIO14 / TXD0) |
| TXD | Pin 10 (GPIO15 / RXD0) |

Do not connect the adapter's power pin. Open a serial terminal at 115200 8N1:

```bash
screen /dev/ttyUSB0 115200
```

(On Windows, use PuTTY or any serial terminal at 115200 8N1.)

## Power up

Insert the SD card and power the Pi. You should see:

```
Hello from bare-metal Raspberry Pi 4 (AArch64)!
Testing exception vector table with a supervisor call (SVC)...
Back from the exception handler - vectors are working!
Blinking the ACT LED as a heartbeat.
```

...and the ACT LED blinking.

## Project layout

```
boot/start.S      - reset entry point, parks secondary cores, zeroes .bss, sets SP
boot/vectors.S    - exception vector table (VBAR_EL1)
src/main.c        - kernel entry: UART up, SVC test, GPIO heartbeat
src/uart.c        - PL011 UART driver (init/putc/getc/puts)
src/gpio.c        - GPIO driver (set output / set / clear)
src/exceptions.c  - exception handlers
include/          - mmio.h, uart.h, gpio.h, exceptions.h
linker.ld         - links at 0x80000 (AArch64 kernel8.img load address)
config.txt        - firmware boot config (arm_64bit=1, enable_uart=1)
Makefile          - cross-compile build (aarch64-linux-gnu)
```

## Roadmap toward a tiny RTOS

1. ARM Generic Timer (`CNTP_*_EL0`) for periodic tick interrupts.
2. GICv2 (BCM2711) interrupt controller setup to route timer IRQs.
3. Context switch (save/restore general + SIMD regs) and a round-robin scheduler.
4. Optionally enable the MMU / page tables.

## Skills demonstrated

- **C** and **ARM (AArch64) assembly** for freestanding, no-libc environments
- **ARMv8-A / AArch64** architecture: exception levels, `VBAR_EL1`, `SVC` handling
- **Bare-metal boot**: reset vector, multi-core parking, `.bss` zeroing, stack setup
- **Peripheral/driver development**: PL011 UART and GPIO via memory-mapped I/O (MMIO)
- **Interrupts & exceptions**: building and installing an exception vector table
- **Toolchain & build**: cross-compiling with `aarch64-linux-gnu`, `Makefile`,
  custom `linker.ld`, `objcopy` to a raw `kernel8.img`
- **Hardware bring-up & debugging**: serial console over USB-TTL at 115200 8N1

## License

Released under the [MIT License](LICENSE).

---

**Keywords:** raspberry-pi-4, rpi4, bare-metal, baremetal, aarch64, arm64, armv8,
bcm2711, osdev, embedded, uart, pl011, gpio, cross-compile, kernel8, interrupts,
exception-vectors, rtos.
