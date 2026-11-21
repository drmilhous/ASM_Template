// NEON integer SIMD: sum 1..43 with ADD on four 32-bit lanes, ADDV to reduce the lanes,
// then a scalar loop for the leftover elements (43 = 10 * 4 + a tail of 3).
// ARM64 counterpart of the x86 AVX2 example (vpaddd).
// Uses the ASM_Template I/O library; see platform.h.
// Build: make 04_integer_sum    (x86 version: ../nasm/04_avx2_integer_sum.asm)

#include "platform.h"

    .globl ASM_MAIN
    .set COUNT, 43                  // 10 full vectors + a tail of 3

    .data
    .balign 16
arr: .word 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30
     .word 31,32,33,34,35,36,37,38,39,40,41,42,43
s_sum: .asciz "sum = "
s_exp: .asciz " (expected 946)"

    .text
    .balign 4
ASM_MAIN:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]

    ADDR x9, arr
    movi v0.4s, #0                  // 4 running sums
    mov  w10, #COUNT                // elements left
1:  cmp  w10, #4
    b.lt 2f                         // fewer than 4 left
    ld1  {v1.4s}, [x9], #16         // load 4 words and advance
    add  v0.4s, v0.4s, v1.4s
    sub  w10, w10, #4
    b    1b

2:  addv s0, v0.4s                  // reduce the 4 lanes to one number
    fmov w19, s0                    // (the value is an integer: just move the bits)
3:  cbz  w10, 4f                    // scalar tail
    ldr  w1, [x9], #4
    add  w19, w19, w1
    sub  w10, w10, #1
    b    3b

4:  PRINT_STR s_sum
    PRINT_INT w19
    PRINT_STR s_exp
    PRINT_NL

    mov  w0, #0
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
