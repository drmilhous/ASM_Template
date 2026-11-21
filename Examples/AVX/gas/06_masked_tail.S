// NEON has no predicate (mask) registers, so a loop tail is handled with a compare that builds a
// lane mask and BSL/BIF to merge the lanes. Here: add arrays of 21 floats = 5 full vectors of 4
// plus a last vector where only 1 lane is real. The arrays are padded so reading all 4 lanes is safe.
// ARM64 counterpart of the x86 AVX-512 opmask example. The real equivalent is SVE predicates:
// see 07_sve_predicate.S.
// Uses the ASM_Template I/O library; see platform.h.
// Build: make 06_masked_tail    (x86 version: ../nasm/06_avx512_mask.asm)

#include "platform.h"

    .globl ASM_MAIN
    .set COUNT, 21

    .data
    .balign 16
a:  .rept 24
    .float 1.5                      // padding beyond COUNT is read but never stored
    .endr
b:  .rept 24
    .float 2.5
    .endr
lane_index: .word 0, 1, 2, 3
s_sum: .asciz "sum of c[0..20] = "
s_exp: .asciz " (expected 84.0)"
    .balign 16
c:  .space 96                       // starts as zero: untouched lanes stay zero

    .text
    .balign 4
ASM_MAIN:
    stp  x29, x30, [sp, #-32]!      // [sp, #16] = spare slot for the result
    mov  x29, sp

    ADDR x9,  a
    ADDR x10, b
    ADDR x11, c
    ADDR x12, lane_index
    ldr  q7, [x12]                  // v7 = {0, 1, 2, 3}
    mov  w13, #0                    // element index
1:  mov  w14, #COUNT
    subs w14, w14, w13              // elements left
    b.le 3f
    ldr  q0, [x9]                   // 4 floats from a
    ldr  q1, [x10]                  // 4 floats from b
    fadd v2.4s, v0.4s, v1.4s
    cmp  w14, #4
    b.ge 2f                         // a full vector: store it all
    dup  v3.4s, w14                 // v3 = {left, left, left, left}
    cmgt v3.4s, v3.4s, v7.4s        // mask lane i = (left > i) ? all ones : 0
    ldr  q4, [x11]                  // the 4 floats currently in c
    bsl  v3.16b, v2.16b, v4.16b     // where mask is set take the sum, else keep c
    mov  v2.16b, v3.16b
2:  str  q2, [x11]
    add  x9, x9, #16
    add  x10, x10, #16
    add  x11, x11, #16
    add  w13, w13, #4
    b    1b

3:  // sum c[0..20] with scalar code to show the result
    ADDR x11, c
    movi d0, #0
    mov  w13, #COUNT
4:  ldr  s1, [x11], #4
    fadd s0, s0, s1
    subs w13, w13, #1
    b.ne 4b
    fcvt d0, s0
    str  d0, [sp, #16]

    PRINT_STR s_sum
    ldr  d0, [sp, #16]
    PRINT_FLOAT
    PRINT_STR s_exp
    PRINT_NL

    mov  w0, #0
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
