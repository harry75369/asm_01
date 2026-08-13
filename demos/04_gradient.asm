; ============================================================
; Demo 4: Color gradient
;
; Draws a horizontal RGB gradient across the screen.
; Left side = red, right side = green, blue varies vertically.
; Demonstrates per-pixel color computation.
;
; Pixel format: 32-bit BGRA
;   byte 0 = Blue, byte 1 = Green, byte 2 = Red, byte 3 = Alpha
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

    mov rcx, [r15 + 8]
    test rcx, rcx
    jz .fail

    ; Get first framebuffer
    mov rdx, [r15 + 16]
    mov rdi, [rdx]

    ; Read params - use callee-saved regs for persistent values
    mov rbx, [rdi + 0]        ; rbx = fb address (preserved)
    mov r8,  [rdi + 8]        ; r8  = width
    mov r9,  [rdi + 16]       ; r9  = height
    mov r10, [rdi + 24]       ; r10 = pitch (preserved, not modified)

    ; r12 = current y (row)
    xor r12, r12

.row_loop:
    cmp r12, r9
    jae .done

    ; blue = 255 * y / height
    mov rax, 255
    imul rax, r12
    xor rdx, rdx
    div r9
    mov r14b, al              ; r14b = blue component (preserved across cols)

    ; r13 = current x (column)
    xor r13, r13

.col_loop:
    cmp r13, r8
    jae .next_row

    ; red = 255 * (width - 1 - x) / (width - 1)
    mov rax, 255
    imul rax, r8
    dec rax
    sub rax, r13
    jns .calc_red
    xor rax, rax
.calc_red:
    xor rdx, rdx
    div r8
    mov r15b, al              ; r15b = red (temporary, r15 no longer needed for response)

    ; green = 255 * x / (width - 1)
    mov rax, 255
    imul rax, r13
    xor rdx, rdx
    div r8
    mov cl, al                ; cl = green

    ; Build BGRA pixel: [blue, green, red, 0xFF]
    movzx rax, r14b           ; blue
    movzx rdx, cl
    shl rdx, 8                ; green << 8
    or  rax, rdx
    movzx rdx, r15b
    shl rdx, 16               ; red << 16
    or  rax, rdx
    mov edx, 0xFF000000
    or  rax, rdx              ; alpha

    ; Calculate pixel address: base + y*pitch + x*4
    mov rdx, r12
    imul rdx, r10             ; y * pitch
    add rdx, rbx              ; + base
    mov [rdx + r13*4], eax    ; + x*4, write pixel

    inc r13
    jmp .col_loop

.next_row:
    inc r12
    jmp .row_loop

.done:
    WAIT_KEY_AND_REBOOT

.fail:
    DEBUG_PUTS msg_fail
    HALT
