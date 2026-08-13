; ============================================================
; Demo 2: Framebuffer Info via debugcon
;
; Requests a framebuffer from Limine and prints its parameters
; (address, width, height, pitch, bpp) to debugcon.
; ============================================================

bits 64
%include "limine.inc"

section .data
    LIMINE_REQUESTS_START
    LIMINE_BASE_REVISION 1
    LIMINE_FRAMEBUFFER_REQUEST
    LIMINE_REQUESTS_END

    msg_addr:    db "FB addr=0x", 0
    msg_width:   db " width=0x", 0
    msg_height:  db " height=0x", 0
    msg_pitch:   db " pitch=0x", 0
    msg_bpp:     db " bpp=0x", 0
    msg_fail:    db "No framebuffer!", 10, 13, 0

section .text
global _start

_start:
    KEEP_REQUESTS
    mov rax, limine_framebuffer_request

    ; Get framebuffer response pointer
    mov r15, [limine_fb_response_ptr]
    test r15, r15
    jz .fail

    ; Check framebuffer count (offset 8)
    mov rcx, [r15 + 8]
    test rcx, rcx
    jz .fail

    ; Get first framebuffer pointer
    mov rdx, [r15 + 16]       ; framebuffers array
    mov rdi, [rdx]            ; first framebuffer struct

    ; Print address
    DEBUG_PUTS msg_addr
    mov rax, [rdi + 0]        ; address
    DEBUG_PUTHEX

    ; Print width
    DEBUG_PUTS msg_width
    mov rax, [rdi + 8]        ; width
    DEBUG_PUTHEX

    ; Print height
    DEBUG_PUTS msg_height
    mov rax, [rdi + 16]       ; height
    DEBUG_PUTHEX

    ; Print pitch
    DEBUG_PUTS msg_pitch
    mov rax, [rdi + 24]       ; pitch
    DEBUG_PUTHEX

    ; Print bpp (uint16_t at offset 32)
    DEBUG_PUTS msg_bpp
    movzx rax, word [rdi + 32]
    DEBUG_PUTHEX

    DEBUG_NEWLINE
    WAIT_KEY_AND_REBOOT

.fail:
    DEBUG_PUTS msg_fail
    HALT
