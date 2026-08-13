; ============================================================
; Demo 5: Draw text on screen
;
; Draws "HELLO!" in white on a blue background using an 8x8
; bitmap font. Demonstrates per-pixel font rendering.
;
; Pixel format: 32-bit BGRA
; ============================================================

bits 64
%include "limine.inc"

section .data
    LIMINE_REQUESTS_START
    LIMINE_BASE_REVISION 1
    LIMINE_FRAMEBUFFER_REQUEST
    LIMINE_REQUESTS_END

    msg_fail: db "No framebuffer!", 10, 13, 0

    ; String to draw (NUL-terminated)
    text: db "HELLO!", 0

    ; 8x8 font data - each char is 8 bytes (8 rows, MSB = leftmost pixel)
    ; Index: 'H'=0, 'E'=1, 'L'=2, 'O'=3, '!'=4
    font_h:
        db 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
    font_e:
        db 0x7E, 0x60, 0x60, 0x78, 0x60, 0x60, 0x7E, 0x00
    font_l:
        db 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00
    font_o:
        db 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00
    font_excl:
        db 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00

    ; Color constants (BGRA: Blue=low, Alpha=high)
    COLOR_BG:    equ 0xFFFF0000   ; red background
    COLOR_WHITE: equ 0xFFFFFFFF   ; white text

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

    ; Read params
    mov rsi, [rdi + 0]        ; fb address
    mov r8,  [rdi + 8]        ; width
    mov r9,  [rdi + 16]       ; height
    mov r10, [rdi + 24]       ; pitch

    ; ---- Step 1: Fill background with blue ----
    mov rcx, r8
    imul rcx, r9              ; total pixels
    push rsi
.fill_bg:
    mov dword [rsi], COLOR_BG
    add rsi, 4
    dec rcx
    jnz .fill_bg
    pop rsi

    ; ---- Step 2: Draw text "HELLO!" ----
    ; Start position: center-ish (x=100, y=100)
    mov r12, 100              ; start x (pixel column)
    mov r13, 100              ; start y (pixel row)

    ; r14 = pointer into text string
    lea r14, [rel text]

.draw_char:
    mov al, [r14]
    test al, al
    jz .done

    ; Look up font data pointer based on character
    lea rbp, [rel font_h]     ; default
    cmp al, 'H'
    je .have_font
    lea rbp, [rel font_e]
    cmp al, 'E'
    je .have_font
    lea rbp, [rel font_l]
    cmp al, 'L'
    je .have_font
    lea rbp, [rel font_o]
    cmp al, 'O'
    je .have_font
    lea rbp, [rel font_excl]
    cmp al, '!'
    je .have_font
    ; Unknown char - skip
    jmp .next_char

.have_font:
    ; Draw 8x8 character at (r12, r13)
    ; rbp = font data (8 bytes)
    xor r15d, r15d            ; row index (0-7)

.font_row:
    cmp r15d, 8
    jae .next_char

    ; Get font row data
    movzx rbx, byte [rbp + r15]  ; bl = font row bitmap

    ; Calculate framebuffer address for this pixel:
    ; addr = fb_base + (y + row) * pitch + (x) * 4
    mov rax, r13
    add rax, r15               ; y + row
    imul rax, r10              ; * pitch
    add rax, r12
    shl rax, 2                 ; * 4 (bytes per pixel)
    add rax, rsi               ; + fb_base
    mov rdi, rax               ; rdi = pixel row start

    ; Draw 8 pixels in this row
    xor ecx, ecx               ; column index (0-7)

.font_col:
    cmp ecx, 8
    jae .font_row_done

    ; Test bit (7 - col) of bl
    ; Shift bl left by col, then test bit 7
    mov al, bl
    shl al, cl                 ; cl = col, bit (7-col) moves to bit 7
    test al, 0x80              ; test bit 7
    jz .skip_pixel

    ; Set pixel to white
    mov dword [rdi], COLOR_WHITE

.skip_pixel:
    add rdi, 4                 ; next pixel
    inc ecx
    jmp .font_col

.font_row_done:
    inc r15d
    jmp .font_row

.next_char:
    add r12, 10               ; advance x by char width + spacing
    inc r14
    jmp .draw_char

.done:
    WAIT_KEY_AND_REBOOT

.fail:
    DEBUG_PUTS msg_fail
    HALT
