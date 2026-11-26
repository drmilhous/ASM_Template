// C main -> asm_main -> re_operation(x0=input, x1=output).
#include "platform.h"
.data
.p2align 4
.globl INPUT, OUTPUT
INPUT: .long 0xc0700000, 0x40100000, 0, 0x7fc00000
OUTPUT: .zero 32
.text
.p2align 2
.globl MAIN, OP
MAIN:
    stp x29, x30, [sp, #-16]!   // preserve LR because BL overwrites it
    mov x29, sp
    ADDRESS x0, INPUT
    ADDRESS x1, OUTPUT
    bl OP
    ldp x29, x30, [sp], #16
    ret
OP:
    ldr s0, [x0]                // -3.75, not the integer 0xc0700000
    ldr s1, [x0, #4]
    fadd s2, s0, s1
    str s2, [x1]
    fcvtzs w8, s0               // convert with truncation toward zero
    str w8, [x1, #4]
    fcmp s0, s1
    cset w8, mi                 // ordered less-than; LT would also include NaN
    str w8, [x1, #8]
    ldr s2, [x0, #12]
    fcmp s2, s2
    cset w8, vs                 // V=1 means unordered
    str w8, [x1, #12]
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
