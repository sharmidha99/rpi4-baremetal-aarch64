# Bare-metal AArch64 build for Raspberry Pi 4 (BCM2711)
# Install toolchain in WSL2 with: sudo apt install gcc-aarch64-linux-gnu

CROSS_COMPILE ?= aarch64-linux-gnu-
CC       := $(CROSS_COMPILE)gcc
LD       := $(CROSS_COMPILE)ld
OBJCOPY  := $(CROSS_COMPILE)objcopy

BUILD_DIR := build
SRC_DIR   := src
BOOT_DIR  := boot
INC_DIR   := include

CFLAGS  := -Wall -Wextra -ffreestanding -nostdlib -nostartfiles \
           -mgeneral-regs-only -O2 -I$(INC_DIR)
LDFLAGS := -T linker.ld -nostdlib -Map=$(BUILD_DIR)/kernel8.map

C_SRCS   := $(wildcard $(SRC_DIR)/*.c)
ASM_SRCS := $(wildcard $(BOOT_DIR)/*.S)

OBJS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(C_SRCS)) \
        $(patsubst $(BOOT_DIR)/%.S,$(BUILD_DIR)/%.o,$(ASM_SRCS))

all: kernel8.img

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(BOOT_DIR)/%.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/kernel8.elf: $(OBJS) linker.ld | $(BUILD_DIR)
	$(LD) $(LDFLAGS) $(OBJS) -o $@

kernel8.img: $(BUILD_DIR)/kernel8.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -rf $(BUILD_DIR) kernel8.img

.PHONY: all clean
