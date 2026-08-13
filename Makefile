.PHONY: all clean run run-uefi iso

BUILD_DIR := build
ISO_DIR := $(BUILD_DIR)/iso
LIMINE_DIR := limine-binary
INCLUDE_DIR := include
DEMOS_DIR := demos

NASM := nasm
LD := ld
XORRISO := xorriso
QEMU := qemu-system-x86_64

LINKER_SCRIPT := link.ld
ISO_IMAGE := $(BUILD_DIR)/kernel.iso

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
	@cp /usr/share/OVMF/OVMF_VARS.fd $(BUILD_DIR)/OVMF_VARS.fd
	$(QEMU) -cdrom $(ISO_IMAGE) -boot d -m 2G -debugcon stdio \
		-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
		-drive if=pflash,format=raw,file=$(BUILD_DIR)/OVMF_VARS.fd

clean:
	rm -rf $(BUILD_DIR)
