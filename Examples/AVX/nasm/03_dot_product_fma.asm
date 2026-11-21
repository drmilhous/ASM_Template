; AVX + FMA3: dot product of two 16-float vectors.
; vfmadd231ps does acc += x * y in one instruction (one rounding step).
; The final step adds the eight lanes of the accumulator together ("horizontal add").
; Portable: Linux, macOS (Intel) and Windows x64 (see platform.inc). Needs a CPU with FMA.
; Build: make 03_dot_product_fma   (Linux/macOS)   or   .\quickBuild.ps1 03_dot_product_fma   (Windows)

%include "platform.inc"
default rel
global MAIN

section .data align=64
    x   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
    y   dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0
    fmt db "dot = %.1f (expected 108.0)", 10, 0

section .text
MAIN:
    push rbx                        ; align the stack for calls

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
    vcvtss2sd xmm0, xmm0, xmm0
    vzeroupper

    lea ARG1, [fmt]
    DOUBLE_ARG2
    mov eax, 1
    CCALL PRINTF

    xor eax, eax
    pop rbx
    ret

GNU_STACK_NOTE
