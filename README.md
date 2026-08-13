# ASM 01

A stupid-simple framework for `x86_64` assembly language programming using `limine` bootloader with the following features:
- Full `x86_64` assembly language programming environment.
  - With Limine protocol support.
  - Full 64-bit long mode with full x86-64 instruction set available (including r8-r15, RIP-relative addressing, REX prefixes, etc.).
  - 64-bit virtual addressing: the kernel is linked at the high half (0xFFFFFFFF80000000), thanks to the 4-level/5-level paging tables Limine sets up before handing control over.
  - Ring 0 privilege: Limine does not drop privileges, so kernel code runs at CPL 0 with full access to all privileged instructions (CR/MSR/port I/O/instructions like `cli`, `hlt`, `wrmsr`).
  - SSE/FPU usable out of the box: Limine initializes FPU and SSE state before entering the kernel, so floating-point and SIMD instructions can be used directly.
- Makes a bootable ISO image for
  - Both QEMU and bare-metal x86_64 systems.
  - Both BIOS and UEFI booting support.
  - Switching between multiple demos.
  - Runtime demo switching: press any key to reboot back to the Limine menu and pick another demo.
  - Burning into a USB drive.

You can start programming by editing the files under `demos`.

# Why

I want to teach kids old-style assembly language programming, however, I don't want
- Teach ancient 8-bit/16-bit/32-bit assembly
- Run assembly on expensive dev-boards with proprietary firmware
- Complex OSes with distracting details

The not-so-obvious choice is x86_64 machines that is ubiquitous and cheap enough, with open standards established long long ago. And assembly could run on bare-metal easily with modern bootloader like Limine.

# Usage

Use `prepare.sh` to prepare the limine environment.

- `make`: Build the ISO image.
- `make run`: Run the ISO image in QEMU.
- `make run-uefi`: Run the ISO image in QEMU with UEFI support.
- `make clean`: Clean the build directory.

# Dependencies

- `nasm` (assembler)
- `ld` (linker, from GNU binutils)
- `xorriso` (ISO builder)
- `qemu-system-x86_64` (test runner)
- `OVMF` firmware blobs (`OVMF_CODE.fd`, `OVMF_VARS.fd`) — required only for `make run-uefi`.

# Writing a new demo

1. Add `demos/NN_name.asm`. Start with `bits 64` and `%include "limine.inc"`.
2. Use the macros from `limine.inc` to declare requests and emit debug output:
   - `LIMINE_REQUESTS_START` / `LIMINE_REQUESTS_END` — bracket the request region.
   - `LIMINE_BASE_REVISION 1` — declare the protocol revision you target.
   - `LIMINE_FRAMEBUFFER_REQUEST` — request a framebuffer (response pointer lands in `limine_fb_response_ptr`).
   - `DEBUG_PUTS label`, `DEBUG_PUTHEX`, `DEBUG_NEWLINE` — write to QEMU's debugcon.
   - `KEEP_REQUESTS` — reference the request symbols so the linker does not GC them.
   - `HALT` — stop the CPU forever (use on failure paths).
   - `WAIT_KEY_AND_REBOOT` — wait for a keypress then reboot back to the Limine menu (use on success paths).
3. Append a new entry to `limine.conf` pointing at `boot():/boot/NN_name.elf`.
4. Add the demo name to the `DEMOS` list in `Makefile`.

# License
[MIT License](https://mit-license.org/)
