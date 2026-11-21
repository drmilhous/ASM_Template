// NEON: dot product of two 16-float vectors with FMLA (fused multiply-add: acc += x * y).
// ARM64 counterpart of the x86 AVX + FMA3 example (vfmadd231ps). The final step adds the four
// lanes of the accumulator together with pairwise adds (faddp), the "horizontal add".
// Uses the ASM_Template I/O library; see platform.h.
// Build: make 03_dot_product_fmla    (x86 version: ../nasm/03_dot_product_fma.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 16
x:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
y:  .float 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0
s_dot: .asciz "dot = "
s_exp: .asciz " (expected 108.0)"

    .text
    .balign 4
ASM_MAIN:
    stp  x29, x30, [sp, #-32]!      // 16 bytes of frame + a spare slot at [sp, #16] for the result
    mov  x29, sp

    ADDR x9,  x
    ADDR x10, y
    movi v2.4s, #0                  // accumulator = 0
    mov  x11, #0
1:  ldr  q0, [x9, x11]
    ldr  q1, [x10, x11]
    fmla v2.4s, v0.4s, v1.4s        // v2 += v0 * v1, lane by lane
    add  x11, x11, #16
    cmp  x11, #64
    b.lo 1b

    // horizontal sum of the 4 lanes in v2
    faddp v2.4s, v2.4s, v2.4s       // (a+b, c+d, a+b, c+d)
    faddp s0, v2.2s                 // (a+b) + (c+d)
    fcvt d0, s0                     // float -> double for print_float
    str  d0, [sp, #16]              // keep it across the print_string call

    PRINT_STR s_dot
    ldr  d0, [sp, #16]
    PRINT_FLOAT
    PRINT_STR s_exp
    PRINT_NL

    mov  w0, #0
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
