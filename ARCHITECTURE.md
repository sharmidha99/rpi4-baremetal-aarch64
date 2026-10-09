# Architecture & Code Walkthrough

This document explains **what each file does** and **how control flows** from
power-on to the running kernel. Read it top-to-bottom to understand the whole
project.

## 1. The big picture

When you power the Raspberry Pi 4, this is the chain of events:

```
Pi 4 firmware (GPU)                         -> loads config.txt, then kernel8.img into RAM at 0x80000
boot/start.S  : _start                      -> runs first, on CPU core 0 only
   |-- park cores 1-3                        (keep only one core running)
   |-- zero .bss                             (clear uninitialised globals)
   |-- set up stack pointer
   |-- switch_to_el1                         (drop from EL2 to EL1)
   |-- install vector table (VBAR_EL1)       (points at boot/vectors.S)
   `-- call main()
src/main.c    : main()                      -> the C entry point
   |-- uart_init()                           (bring up serial console)
   |-- puts(...) greetings
   |-- trigger "svc #0"                      (test exception handling)
   |     `-> hardware jumps into vectors.S -> exception_handler() -> returns
   |-- gpio_set_output(ACT LED)
   `-- infinite loop: blink the ACT LED
```

Everything below describes each piece in that chain.

---

## 2. Boot and firmware configuration

### `config.txt`
Read by the **Pi 4 firmware** (not by our code) before anything runs. It tells
the firmware how to start us:

- `arm_64bit=1` — boot the CPU in 64-bit (AArch64) mode.
- `kernel=kernel8.img` — the binary to load.
- `enable_uart=1` — keep the UART clock enabled so our serial console works.
- `uart_2ndstage=1` — extra firmware UART logging (handy while debugging boot).

The firmware copies `kernel8.img` into RAM at physical address **`0x80000`** and
jumps to it. That address is why everything is linked at `0x80000` (see
`linker.ld`).

### `linker.ld`
The **linker script**. It decides the memory layout of the final image:

- `ENTRY(_start)` — execution begins at the `_start` symbol.
- `. = 0x80000;` — the image is placed at `0x80000`, matching where the firmware
  loads it.
- `.text.boot` is forced **first** (`KEEP`) so `_start` is literally the first
  instruction in the image.
- `. = ALIGN(0x800)` then `.text.vectors` — the exception vector table must be
  2 KB aligned (a hardware requirement of `VBAR_EL1`), so the script aligns it.
- `__bss_start` / `__bss_end` — markers around the `.bss` section that `start.S`
  uses to know what memory to zero.

### `Makefile`
Cross-compiles and links everything:

1. Compiles each `src/*.c` and `boot/*.S` into `build/*.o` using
   `aarch64-linux-gnu-gcc` with `-ffreestanding -nostdlib` (no OS, no libc).
2. Links them with `linker.ld` into `build/kernel8.elf`.
3. `objcopy -O binary` strips the ELF wrapper to produce a raw **`kernel8.img`**
   — the exact bytes the firmware loads at `0x80000`.

---

## 3. The boot stub — `boot/start.S`

This is the **first code that runs**. Key steps:

1. **Park secondary cores.** All four cores start executing `_start`. It reads
   `mpidr_el1`, keeps core 0, and sends cores 1-3 into a low-power `wfe` loop
   (`hang`). This keeps the rest of the kernel single-core and simple.
2. **Zero `.bss`.** Uninitialised C globals must start as zero. It loops from
   `__bss_start` to `__bss_end` (symbols from `linker.ld`) writing zeros.
3. **Set up the stack.** `sp` is set to `_start` (i.e. `0x80000`); the stack
   grows *downward* from there, into the memory below the kernel.
4. **`switch_to_el1`.** The firmware usually hands control over at **EL2**
   (hypervisor level). This routine drops to **EL1** so that one exception level
   is used consistently for `VBAR_EL1`, and later the timer/GIC/MMU. It does this
   by configuring `HCR_EL2` (EL1 is AArch64), `SPSR_EL2` (target state, all
   interrupts masked for now), `ELR_EL2` (return address), then `eret`.
5. **Install the vector table.** `msr vbar_el1, =vectors` points the CPU at the
   table in `vectors.S`, so any exception now lands in our handlers.
6. **`bl main`** — jump into C.

---

## 4. Exception handling

### `boot/vectors.S`
The **exception vector table** required by ARMv8-A. Details:

- It is `.align 11` (2 KB aligned) because `VBAR_EL1` requires it.
- It has **16 entries**, in 4 groups of 4 (Synchronous / IRQ / FIQ / SError),
  for the 4 exception sources (current EL on SP0, current EL on SPx, lower EL in
  AArch64, lower EL in AArch32). Each entry is 128 bytes (`.align 7`).
- We only genuinely use the **"Current EL, SP_ELx" (EL1h)** group, since we run
  at EL1 and never drop to EL0. The others are wired up anyway so unexpected
  faults are reported instead of hanging silently.
- The `handler_entry` macro is the **save/restore trampoline**: it pushes all
  general-purpose registers `x0`-`x30` onto the stack, loads the diagnostic
  system registers (`ESR_EL1`, `ELR_EL1`, `FAR_EL1`) into arguments, calls the C
  function `exception_handler`, then restores the registers and returns with
  `eret` (which resumes exactly where the exception occurred).

### `src/exceptions.c`
The **C exception handler** called by the trampoline. It:

- Maps the numeric `type` (0-15) to a human-readable name via
  `exception_names[]`.
- Prints the exception name plus the key registers in hex:
  - `ESR_EL1` — *why* it happened (exception syndrome / cause).
  - `ELR_EL1` — *where* execution will resume.
  - `FAR_EL1` — the faulting address (for memory faults).
- `print_hex64()` is a tiny hand-rolled hex formatter (no `printf` exists here).

### `include/exceptions.h`
Declares `exception_handler(type, esr, elr, far)` and documents each argument.

**Why it matters:** In `main.c`, the line `asm volatile("svc #0")` deliberately
raises a *synchronous* exception. The CPU jumps into `vectors.S` → the EL1h sync
entry → `handler_entry 4` → `exception_handler()`, which prints the details, then
`eret` returns to the instruction after the `svc`. This proves the whole
exception path is wired up correctly.

---

## 5. Device drivers (memory-mapped I/O)

### `include/mmio.h`
The foundation for all hardware access. On the Pi 4 (BCM2711), peripherals are
controlled by reading/writing fixed memory addresses:

- `PERIPHERAL_BASE = 0xFE000000` — base of the peripheral region (low-peripheral
  mode).
- `GPIO_BASE`, `UART0_BASE` — offsets to the GPIO and PL011 UART blocks.
- `mmio_write()` / `mmio_read()` — `volatile` 32-bit accesses. `volatile` is
  essential so the compiler never caches or reorders hardware register accesses.

### `src/uart.c` + `include/uart.h`
A driver for the **PL011 UART** (the serial console). `uart_init()`:

1. Disables the UART while reconfiguring.
2. Routes **GPIO14/15 to ALT0** (TXD0/RXD0) via `GPFSEL1`.
3. Disables pull-up/down on those pins (BCM2711 `GPPUPPDN0` scheme).
4. Sets the baud rate to **115200** (integer/fractional divisors `IBRD`/`FBRD`
   for a 48 MHz UART clock).
5. Configures **8N1** with FIFOs enabled (`LCRH`), masks interrupts, then enables
   the UART with TX and RX.

Then:
- `uart_putc()` — spins until the TX FIFO has room, then writes a byte.
- `uart_getc()` — spins until the RX FIFO has a byte, then reads it.
- `uart_puts()` — writes a string, translating `\n` into `\r\n` for terminals.

### `src/gpio.c` + `include/gpio.h`
A minimal **GPIO** driver:

- `gpio_set_output(pin)` — sets a pin's function to *output*. GPIO function
  registers pack 3 bits per pin, 10 pins per 32-bit register, so it computes the
  register index (`pin / 10`) and bit shift (`(pin % 10) * 3`).
- `gpio_set(pin)` / `gpio_clear(pin)` — drive the pin high/low using the
  set/clear registers (1 bit per pin, 32 pins per register).

The ACT LED is on GPIO **42**, which is what `main.c` toggles.

---

## 6. The kernel entry — `src/main.c`

The C `main()` ties everything together:

1. `uart_init()` — bring up the serial console.
2. Print the greeting banner.
3. `asm volatile("svc #0")` — fire a test exception (see section 4). The handler
   prints its diagnostics, then control returns to the next line.
4. Print confirmation that vectors work.
5. `gpio_set_output(42)` — configure the ACT LED pin as output.
6. **Infinite loop**: set the LED, busy-delay, clear the LED, busy-delay — a
   visible "heartbeat" so you know the kernel is alive. `delay()` is a simple
   `nop` spin loop (no timer yet).

---

## 7. How it all links together (summary table)

| File | Role | Entry point / key symbol |
|---|---|---|
| `config.txt` | Firmware boot config | read by GPU firmware |
| `linker.ld` | Memory layout, load at `0x80000` | `ENTRY(_start)` |
| `boot/start.S` | Boot stub: cores, bss, stack, EL1, vectors | `_start` |
| `boot/vectors.S` | Exception vector table + save/restore | `vectors` |
| `src/exceptions.c` | C exception reporting | `exception_handler()` |
| `src/main.c` | Kernel logic | `main()` |
| `src/uart.c` | PL011 UART driver | `uart_init/putc/getc/puts` |
| `src/gpio.c` | GPIO driver | `gpio_set_output/set/clear` |
| `include/mmio.h` | MMIO read/write + peripheral bases | `mmio_read/write` |

---

## 8. Where to go next

The code is deliberately structured so the next RTOS steps slot in cleanly:

1. **Timer interrupts** — program the ARM Generic Timer (`CNTP_*_EL0`) and unmask
   IRQs; the IRQ path in `vectors.S` is already in place.
2. **GICv2** — set up the BCM2711 interrupt controller to route the timer IRQ.
3. **Scheduler** — on each timer tick, save/restore register context (the
   trampoline in `vectors.S` already shows the pattern) and switch between tasks.
