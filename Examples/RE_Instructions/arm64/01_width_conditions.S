// C main -> asm_main -> re_operation(x0=input, x1=output).
#include "platform.h"
.data
.p2align 4
.globl INPUT, OUTPUT
INPUT: .long 0xff, 0xfffffff9, 3, 0
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
    // Signed/unsigned byte loads, then store 32-bit representations.
    ldrsb w8, [x0]
    str w8, [x1]
    ldrb w8, [x0]
    str w8, [x1, #4]
    ldr w8, [x0, #4]
    ldr w9, [x0, #8]
    cmp w8, w9
    csel w10, w8, w9, lt // signed minimum
    str w10, [x1, #8]
    cset w10, lo         // original comparison, unsigned less-than
    str w10, [x1, #12]
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
