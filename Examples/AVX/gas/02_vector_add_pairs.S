// NEON: eight floats per loop pass using two q registers and load/store PAIRS (ldp/stp).
// ARM64 counterpart of the x86 AVX example (ymm = 8 floats): NEON registers are only 128 bits wide,
// so a wider step means more registers. Like AVX, every operation has a separate destination.
// Uses the ASM_Template I/O library; see platform.h.
// Build: make 02_vector_add_pairs    (x86 version: ../nasm/02_vector_add_avx.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 16
a:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0
b:  .float 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0
s_open:  .asciz "c["
s_close: .asciz "] = "
    .balign 16
c:  .space 64

    .text
    .balign 4
ASM_MAIN:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]

    ADDR x9,  a
    ADDR x10, b
    ADDR x19, c
    mov  x12, x19                   // store pointer
    mov  w11, #16                   // floats left
1:  ldp  q0, q1, [x9], #32          // 8 floats of a (two registers), then advance the pointer
    ldp  q2, q3, [x10], #32         // 8 floats of b
    fadd v4.4s, v0.4s, v2.4s
    fadd v5.4s, v1.4s, v3.4s
    stp  q4, q5, [x12], #32
    subs w11, w11, #8
    b.ne 1b

    mov  w20, #0
2:  PRINT_STR s_open
    PRINT_INT w20
    PRINT_STR s_close
    ldr  s0, [x19, w20, uxtw #2]
    fcvt d0, s0
    PRINT_FLOAT
    PRINT_NL
    add  w20, w20, #1
    cmp  w20, #16
    b.lo 2b

    mov  w0, #0
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
