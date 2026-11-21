; AVX: the same addition, eight floats at a time (ymm = 256 bits).
; New in AVX: VEX encoding with a separate destination (c = a + b without destroying a).
; Portable: Linux, macOS (Intel) and Windows x64 (see platform.inc).
; Build: make 02_vector_add_avx   (Linux/macOS)   or   .\quickBuild.ps1 02_vector_add_avx   (Windows)

%include "platform.inc"
default rel
global MAIN

section .data align=64
    a   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0
    b   dd 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0
    fmt db "c[%d] = %.1f", 10, 0

section .bss align=64
    c   resd 16

section .text
MAIN:
    push rbx
    push r12
    push r13

    lea r8,  [a]
    lea r9,  [b]
    lea r10, [c]
    xor ecx, ecx
.loop:
    vmovaps ymm0, [r8 + rcx]        ; 8 floats (32-byte aligned data)
    vaddps  ymm1, ymm0, [r9 + rcx]  ; ymm1 = ymm0 + b; ymm0 is kept (3-operand form)
    vmovaps [r10 + rcx], ymm1
    add ecx, 32
    cmp ecx, 64                     ; 16 floats * 4 bytes
    jb .loop
    vzeroupper                      ; clear the upper halves before calling non-AVX code

    xor ebx, ebx
.print:
    lea ARG1, [fmt]
    mov ARG2D, ebx
    lea rax, [c]
    vcvtss2sd xmm0, xmm0, [rax + rbx*4]
    DOUBLE_ARG3
    mov eax, 1
    CCALL PRINTF
    inc ebx
    cmp ebx, 16
    jb .print

    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

GNU_STACK_NOTE
