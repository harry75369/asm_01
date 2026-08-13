; ============================================================
; limine.inc - Limine Bootloader Protocol Definitions for NASM
;
; Provides macros for setting up Limine requests and helper
; macros for debugcon output. All request structures must be
; placed in the .data section.
;
; ----------------------------------------------------------------
; Magic / UUID Constants Reference
; (All are protocol-defined random UUIDs from limine.h; no
;  mathematical meaning. Limine scans the kernel image for these
;  byte patterns to locate requests.)
;
; LIMINE_REQUESTS_START_MARKER (4 qwords = boundary tag)
;   0xf6b8f4b39de7d1ae, 0xfab91a6940fcb9cf,
;   0x785c6ed015d3e316, 0x181e920a7852b9d9
;   → Limine.c: when matched, resets requests_count=0 and
;     begins collecting subsequent request structures.
;
; LIMINE_REQUESTS_END_MARKER (2 qwords = boundary tag)
;   0xadc0e0531bb10d03, 0x9572709f31764c62
;   → Limine.c: when matched, breaks out of the scan loop.
;
; LIMINE_BASE_REVISION (2 qword tag + 1 qword revision number)
;   Tag:  0xf9562b2d5c95a6c8, 0x6a7b384944536bdc
;   Rev:  user-specified (we use 1)
;   → Limine.c: reads rev, writes back:
;       p[1] = actually-supported base revision
;       p[2] = 0 if supported, else downgraded rev
;
; LIMINE_COMMON_MAGIC (2 qwords = every request's prefix)
;   0xc7b1dd30df4c8b88, 0x0a82e883a194f07b
;   → Fast filter in Limine.c: any 32-byte block starting with
;     these 16 bytes is treated as a request candidate; the
;     trailing 2 qwords determine which request type it is.
;
; LIMINE_FRAMEBUFFER_REQUEST_ID trailing 2 qwords
;   0x9d5827dcd881dd75, 0xa3148604f6fab11b
;   → (Common_Magic + these 2 qwords) uniquely identifies the
;     framebuffer request; Limine fills in the response pointer
;     at offset 40 of this struct after setting up VBE/GOP.
; ----------------------------------------------------------------
; ============================================================

; ================ Magic Values ================
%define LIMINE_COMMON_MAGIC_0  0xc7b1dd30df4c8b88
%define LIMINE_COMMON_MAGIC_1  0x0a82e883a194f07b

; ================ Request Structure Macros ================
; Place these in section .data

; Start marker - marks the beginning of Limine requests
%macro LIMINE_REQUESTS_START 0
    align 8
limine_requests_start:
    dq 0xf6b8f4b39de7d1ae
    dq 0xfab91a6940fcb9cf
    dq 0x785c6ed015d3e316
    dq 0x181e920a7852b9d9
%endmacro

; End marker - marks the end of Limine requests
%macro LIMINE_REQUESTS_END 0
    align 8
limine_requests_end:
    dq 0xadc0e0531bb10d03
    dq 0x9572709f31764c62
%endmacro

; Base revision request
; Argument: requested revision (e.g. 1)
%macro LIMINE_BASE_REVISION 1
    align 8
limine_base_revision:
    dq 0xf9562b2d5c95a6c8
    dq 0x6a7b384944536bdc
    dq %1
%endmacro

; Framebuffer request
; Defines symbol: limine_fb_response_ptr (response pointer, offset 40)
%macro LIMINE_FRAMEBUFFER_REQUEST 0
    align 8
limine_framebuffer_request:
    dq LIMINE_COMMON_MAGIC_0
    dq LIMINE_COMMON_MAGIC_1
    dq 0x9d5827dcd881dd75
    dq 0xa3148604f6fab11b
    dq 0                     ; revision
limine_fb_response_ptr:
    dq 0                     ; response
%endmacro

; ================ Debugcon Output Macros ================
; Port 0xE9 is QEMU's debugcon port

; Output a single immediate character to debugcon
; Usage: DEBUG_PUTC 'H'
; Clobbers: al
%macro DEBUG_PUTC 1
    mov al, %1
    out 0xE9, al
%endmacro

; Output a NUL-terminated string to debugcon
; Usage: DEBUG_PUTS msg_label
; Clobbers: rax, rsi
%macro DEBUG_PUTS 1
    mov rsi, %1
%%loop:
    mov al, [rsi]
    test al, al
    jz %%done
    out 0xE9, al
    inc rsi
    jmp %%loop
%%done:
%endmacro

; Output a newline (LF + CR) to debugcon
; Clobbers: al
%macro DEBUG_NEWLINE 0
    mov al, 10
    out 0xE9, al
    mov al, 13
    out 0xE9, al
%endmacro

; Output RAX as 16-char hex to debugcon
; Value must be in RAX before calling
; Clobbers: rax, rbx, rcx, rdx
%macro DEBUG_PUTHEX 0
    mov rbx, rax              ; save value (al gets clobbered by output)
    mov rcx, 60
%%loop:
    mov rdx, rbx
    shr rdx, cl
    and rdx, 0x0F
    add dl, '0'
    cmp dl, '9'
    jbe %%out
    add dl, 7
%%out:
    mov al, dl
    out 0xE9, al
    sub rcx, 4
    jns %%loop
%endmacro

; ================ Utility Macros ================

; Halt the CPU forever
%macro HALT 0
%%halt:
    hlt
    jmp %%halt
%endmacro

; Reference Limine request symbols to prevent linker from discarding them
; Call this at the start of _start
%macro KEEP_REQUESTS 0
    mov rax, limine_requests_start
    mov rax, limine_requests_end
    mov rax, limine_base_revision
%endmacro
