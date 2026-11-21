; AVX + FMA3: dot product of two 16-float vectors.
; vfmadd231ps does acc += x * y in one instruction (one rounding step).
; The final step adds the eight lanes of the accumulator together ("horizontal add").
; Needs a CPU with FMA. Uses the ASM_Template I/O library; see platform.inc.
; Build: make 03_dot_product_fma   (Linux/macOS)   or   .\quickBuild.ps1 03_dot_product_fma   (Windows)

%include "platform.inc"
default rel
global ASM_MAIN

section .data align=64
    x   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
    y   dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0
    s_dot  db "dot = ", 0
    s_exp  db " (expected 108)", 0

section .text
ASM_MAIN:
    push rbp
    mov rbp, rsp
    push rbx                        ; callee-saved: survives the library calls
    sub rsp, 8                      ; keeps the stack 16-byte aligned

    lea r8, [x]
    lea r9, [y]
    vxorps ymm2, ymm2, ymm2         ; accumulator = 0
    xor ecx, ecx
.loop:
    vmovaps ymm0, [r8 + rcx]
    vfmadd231ps ymm2, ymm0, [r9 + rcx]  ; ymm2 += ymm0 * y[i..i+7]
    add ecx, 32
    cmp ecx, 64
    jb .loop

    ; horizontal sum of the 8 lanes in ymm2
    vextractf128 xmm1, ymm2, 1      ; upper 4 lanes
    vaddps  xmm0, xmm2, xmm1        ; 8 -> 4 partial sums
    vhaddps xmm0, xmm0, xmm0        ; 4 -> 2
    vhaddps xmm0, xmm0, xmm0        ; 2 -> 1
    vcvttss2si ebx, xmm0            ; whole number for print_int
    vzeroupper

    PRINT_STR s_dot
    PRINT_INT ebx
    PRINT_STR s_exp
    PRINT_NL

    xor eax, eax
    add rsp, 8
    pop rbx
    pop rbp
    ret

GNU_STACK_NOTE
