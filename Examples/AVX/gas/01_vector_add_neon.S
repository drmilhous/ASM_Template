// NEON: add two float arrays four floats at a time (v registers are 128 bits: 4 x float32).
// ARM64 equivalent of the x86 SSE example. GNU as syntax: destination FIRST, like Intel.
// Uses the ASM_Template I/O library (print_int, print_string, print_float, print_nl); see platform.h.
// Build: make 01_vector_add_neon     (x86 versions: ../nasm/01_vector_add_sse.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 16
a:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0     // 8 floats = 2 q registers
b:  .float 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0
s_open:  .asciz "c["
s_close: .asciz "] = "
    .balign 16
c:  .space 32

    .text
    .balign 4
ASM_MAIN:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]        // callee-saved: they survive the library calls

    ADDR x9,  a
    ADDR x10, b
    ADDR x19, c
    mov  x11, #0                    // byte offset
1:  ldr  q0, [x9, x11]              // load 4 floats
    ldr  q1, [x10, x11]
    fadd v2.4s, v0.4s, v1.4s        // 4 additions in one instruction (three operands: v0 and v1 are kept)
    str  q2, [x19, x11]
    add  x11, x11, #16
    cmp  x11, #32                   // 8 floats * 4 bytes
    b.lo 1b

    mov  w20, #0                    // print c[i] = value
2:  PRINT_STR s_open
    PRINT_INT w20
    PRINT_STR s_close
    ldr  s0, [x19, w20, uxtw #2]    // one float
    fcvt d0, s0                     // float -> double for print_float
    PRINT_FLOAT
    PRINT_NL
    add  w20, w20, #1
    cmp  w20, #8
    b.lo 2b

    mov  w0, #0
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
