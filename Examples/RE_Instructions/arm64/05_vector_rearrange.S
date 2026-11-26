// C main -> asm_main -> re_operation(x0=input, x1=output).
#include "platform.h"
.data
.p2align 4
.globl INPUT, OUTPUT
INPUT: .long 1, 2, 1, 4
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
    ldr q0, [x0]               // all 128 bits of vector V0
    rev64 v1.4s, v0.4s         // swap the two words inside each 64-bit half
    ext v1.16b, v1.16b, v1.16b, #8 // swap halves: full four-word reversal
    str q1, [x1]
    movi v2.4s, #1
    cmeq v2.4s, v0.4s, v2.4s  // equal lanes contain all ones
    str q2, [x1, #16]
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
