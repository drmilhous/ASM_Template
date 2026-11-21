; AVX: the same addition, eight floats at a time (ymm = 256 bits).
; New in AVX: VEX encoding with a separate destination (c = a + b without destroying a).
; Uses the ASM_Template I/O library (print_int, print_string, print_nl); see platform.inc.
; Build: make 02_vector_add_avx   (Linux/macOS)   or   .\quickBuild.ps1 02_vector_add_avx   (Windows)

%include "platform.inc"
default rel
global ASM_MAIN

section .data align=64
    a   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0
    b   dd 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0
    s_open  db "c[", 0
    s_close db "] = ", 0

section .bss align=64
    c   resd 16

section .text
ASM_MAIN:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    lea r8,  [a]
    lea r9,  [b]
    lea r12, [c]
    xor ecx, ecx
.loop:
    vmovaps ymm0, [r8 + rcx]        ; 8 floats (32-byte aligned data)
    vaddps  ymm1, ymm0, [r9 + rcx]  ; ymm1 = ymm0 + b; ymm0 is kept (3-operand form)
    vmovaps [r12 + rcx], ymm1
    add ecx, 32
    cmp ecx, 64                     ; 16 floats * 4 bytes
    jb .loop
    vzeroupper                      ; clear the upper halves before calling non-AVX code

    xor ebx, ebx
.print:
    PRINT_STR s_open
    PRINT_INT ebx
    PRINT_STR s_close
    cvttss2si eax, [r12 + rbx*4]
    PRINT_INT eax
    PRINT_NL
    inc ebx
    cmp ebx, 16
    jb .print

    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret

GNU_STACK_NOTE
