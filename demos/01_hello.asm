; ============================================================
; Demo 1: Hello World via debugcon
;
; The simplest demo - outputs "Hello, Limine!" to QEMU's
; debugcon port (0xE9). No framebuffer needed.
; ============================================================

bits 64
%include "limine.inc"

section .data
    LIMINE_REQUESTS_START
    LIMINE_BASE_REVISION 1
    LIMINE_REQUESTS_END

    msg: db "Hello, Limine!", 10, 13, 0

section .text
global _start

_start:
    KEEP_REQUESTS

    ; Output the message to debugcon
    DEBUG_PUTS msg

    HALT
