.PHONY: all clean run run-uefi iso demos usb-init deploy deploy-usb eject

BUILD_DIR := build
ISO_DIR := $(BUILD_DIR)/iso
LIMINE_DIR := limine-binary
INCLUDE_DIR := include
DEMOS_DIR := demos

# ---- Host OS detection (macOS vs Linux) ----
UNAME_S := $(shell uname -s)

NASM := nasm
XORRISO := xorriso
QEMU := qemu-system-x86_64

# Linker: must be a GNU ld that emits ELF64. Apple's /usr/bin/ld (macOS) cannot,
# so on macOS prefer a cross/binutils ld (e.g. `brew install x86_64-elf-binutils`).
# Note: GNU Make predefines LD=ld (origin "default"), so we also override that.
# Override anytime with: make LD=/path/to/ld
ifneq ($(filter undefined default,$(origin LD)),)
  ifeq ($(UNAME_S),Darwin)
    LD := $(firstword $(shell command -v x86_64-elf-ld 2>/dev/null) \
                      $(shell command -v gnu-ld 2>/dev/null) \
                      $(shell command -v gld 2>/dev/null))
  else
    LD := $(firstword $(shell command -v x86_64-elf-ld 2>/dev/null) \
                      $(shell command -v ld 2>/dev/null))
  endif
endif

LINKER_SCRIPT := link.ld
ISO_IMAGE := $(BUILD_DIR)/kernel.iso

# ---- Real-machine USB deployment (UEFI) ----
# One-time: format a FAT32 stick labeled $(USB_LABEL) (see README), then `make usb-init`.
# Fast loop: `make deploy` copies only the rebuilt ELFs + limine.conf (no dd, no sudo).
# Override the mount point if auto-detection fails: `make deploy USB_MOUNT=/your/path`.
USB_LABEL ?= LIMINE
EFI_BIN   := $(LIMINE_DIR)/BOOTX64.EFI
ifeq ($(UNAME_S),Darwin)
  USB_MOUNT ?= $(shell [ -d "/Volumes/$(USB_LABEL)" ] && echo "/Volumes/$(USB_LABEL)")
  EJECT_CMD  = diskutil eject "$(USB_MOUNT)"
else
  USB_MOUNT ?= $(shell findmnt -rn -o TARGET -L LABEL=$(USB_LABEL) 2>/dev/null || \
    { [ -d "/media/$$USER/$(USB_LABEL)" ] && echo "/media/$$USER/$(USB_LABEL)"; } || \
    { [ -d "/mnt/$(USB_LABEL)" ] && echo "/mnt/$(USB_LABEL)"; })
  EJECT_CMD  = sync; udisksctl unmount -p "$(USB_MOUNT)" 2>/dev/null || echo "==> synced; remove $(USB_MOUNT) safely"
endif

# ---- UEFI firmware for `make run-uefi` ----
# Override with: make run-uefi OVMF_CODE=/path/code.fd OVMF_VARS_TEMPLATE=/path/vars.fd
ifeq ($(UNAME_S),Darwin)
  QEMU_SHARE := $(firstword $(wildcard $(shell brew --prefix 2>/dev/null)/share/qemu) \
    $(wildcard /opt/homebrew/share/qemu) $(wildcard /usr/local/share/qemu))
  OVMF_CODE ?= $(QEMU_SHARE)/edk2-x86_64-code.fd
  OVMF_VARS_TEMPLATE ?= $(QEMU_SHARE)/edk2-i386-vars.fd
else
  OVMF_CODE ?= /usr/share/OVMF/OVMF_CODE.fd
  OVMF_VARS_TEMPLATE ?= /usr/share/OVMF/OVMF_VARS.fd
endif
OVMF_VARS := $(BUILD_DIR)/OVMF_VARS.fd

# Demo list (ordered by complexity)
DEMOS := 01_hello 02_fbinfo 03_fill 04_gradient 05_text

# Generate ELF and object file paths
DEMO_ELFS := $(foreach demo,$(DEMOS),$(BUILD_DIR)/$(demo).elf)
DEMO_OBJS := $(foreach demo,$(DEMOS),$(BUILD_DIR)/$(demo).o)

all: iso

# Compile a single demo object file
$(BUILD_DIR)/%.o: $(DEMOS_DIR)/%.asm
	@mkdir -p $(BUILD_DIR)
	$(NASM) -f elf64 -I $(INCLUDE_DIR)/ $< -o $@

# Link a single demo ELF
$(BUILD_DIR)/%.elf: $(BUILD_DIR)/%.o $(LINKER_SCRIPT)
	@test -n "$(LD)" || { echo "No GNU ld found. macOS: brew install x86_64-elf-binutils; Linux: install binutils. Or run: make LD=/path/to/ld"; exit 1; }
	$(LD) -T $(LINKER_SCRIPT) $< -o $@

# Build all demos
demos: $(DEMO_ELFS)

iso: $(ISO_IMAGE)

$(ISO_IMAGE): $(DEMO_ELFS) limine.conf
	@mkdir -p $(ISO_DIR)/EFI/BOOT
	@mkdir -p $(ISO_DIR)/boot
	@cp $(DEMO_ELFS) $(ISO_DIR)/boot/
	@cp $(LIMINE_DIR)/limine-bios-cd.bin $(ISO_DIR)/
	@cp $(LIMINE_DIR)/limine-uefi-cd.bin $(ISO_DIR)/
	@cp $(LIMINE_DIR)/limine-bios.sys $(ISO_DIR)/
	@cp $(LIMINE_DIR)/BOOTX64.EFI $(ISO_DIR)/EFI/BOOT/
	@cp limine.conf $(ISO_DIR)/
	@cp limine.conf $(ISO_DIR)/boot/limine.conf
	$(XORRISO) -as mkisofs \
		-R -r -J \
		-o $@ \
		-b limine-bios-cd.bin \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-hfsplus \
		-apm-block-size 2048 \
		--efi-boot limine-uefi-cd.bin \
		-efi-boot-part \
		--efi-boot-image \
		--protective-msdos-label \
		$(ISO_DIR)
	$(LIMINE_DIR)/limine bios-install $@

run: $(ISO_IMAGE)
	$(QEMU) -cdrom $(ISO_IMAGE) -boot d -m 2G -debugcon stdio

run-uefi: $(ISO_IMAGE)
	@test -f "$(OVMF_CODE)" || { echo "UEFI firmware not found: $(OVMF_CODE)"; echo "  install OVMF/edk2, or: make run-uefi OVMF_CODE=/path/code.fd OVMF_VARS_TEMPLATE=/path/vars.fd"; exit 1; }
	@test -f "$(OVMF_VARS_TEMPLATE)" || { echo "UEFI vars template not found: $(OVMF_VARS_TEMPLATE)"; exit 1; }
	@cp "$(OVMF_VARS_TEMPLATE)" $(OVMF_VARS)
	$(QEMU) -cdrom $(ISO_IMAGE) -boot d -m 2G -debugcon stdio \
		-drive if=pflash,format=raw,readonly=on,file="$(OVMF_CODE)" \
		-drive if=pflash,format=raw,file=$(OVMF_VARS)

# ---- Real-machine USB workflow (UEFI) ----
# One-time: lay the UEFI bootloader + config + kernels onto the FAT32 stick.
usb-init: $(DEMO_ELFS)
	@test -n "$(USB_MOUNT)" || { echo "USB not found (label '$(USB_LABEL)'). Format it as FAT32 per README, or: make usb-init USB_MOUNT=/path"; exit 1; }
	@mkdir -p "$(USB_MOUNT)/EFI/BOOT" "$(USB_MOUNT)/boot"
	@cp "$(EFI_BIN)" "$(USB_MOUNT)/EFI/BOOT/BOOTX64.EFI"
	@cp limine.conf "$(USB_MOUNT)/limine.conf"
	@cp limine.conf "$(USB_MOUNT)/boot/limine.conf"
	@cp $(DEMO_ELFS) "$(USB_MOUNT)/boot/"
	@sync
	@echo "==> USB ready at $(USB_MOUNT) (run 'make eject' before unplugging)"

# Fast loop: refresh only the rebuilt kernels + config (no dd, no sudo).
deploy deploy-usb: $(DEMO_ELFS)
	@test -n "$(USB_MOUNT)" || { echo "USB not found (label '$(USB_LABEL)'). Run: make deploy USB_MOUNT=/path"; exit 1; }
	@mkdir -p "$(USB_MOUNT)/boot"
	@cp $(DEMO_ELFS) "$(USB_MOUNT)/boot/"
	@cp limine.conf "$(USB_MOUNT)/limine.conf"
	@cp limine.conf "$(USB_MOUNT)/boot/limine.conf"
	@sync
	@echo "==> Deployed to $(USB_MOUNT) (run 'make eject' before unplugging)"

# Safely eject/unmount so writes flush before unplugging.
eject:
	@test -n "$(USB_MOUNT)" || { echo "USB not found (label '$(USB_LABEL)')"; exit 1; }
	$(EJECT_CMD)

clean:
	rm -rf $(BUILD_DIR)
