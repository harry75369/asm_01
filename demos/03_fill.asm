; ============================================================
; Demo 3: Fill screen with a solid color
;
; Requests a framebuffer and fills the entire screen with red.
; Pixel format: 32-bit BGRA (Blue=low byte, Alpha=high byte)
; Red = 0xFFFF0000
; ============================================================

bits 64
%include "limine.inc"

section .data
    LIMINE_REQUESTS_START
    LIMINE_BASE_REVISION 1
    LIMINE_FRAMEBUFFER_REQUEST
    LIMINE_REQUESTS_END

    msg_fail: db "No framebuffer!", 10, 13, 0

section .text
global _start

_start:
    KEEP_REQUESTS
    mov rax, limine_framebuffer_request

    ; Get framebuffer response
    mov r15, [limine_fb_response_ptr]
    test r15, r15
    jz .fail

    ; Check count
    mov rcx, [r15 + 8]
    test rcx, rcx
    jz .fail

    ; Get first framebuffer
    mov rdx, [r15 + 16]
    mov rdi, [rdx]

    ; Read framebuffer params
    mov rsi, [rdi + 0]        ; address
    mov r9,  [rdi + 8]        ; width
    mov r10, [rdi + 16]       ; height

    ; Calculate total pixels = width * height
    mov rcx, r9
    imul rcx, r10

    ; Fill with red (BGRA: 0x00, 0x00, 0xFF, 0xFF)
.fill:
    mov dword [rsi], 0xFFFF0000
    add rsi, 4
    dec rcx
    jnz .fill

    HALT

.fail:
    DEBUG_PUTS msg_fail
    HALT
