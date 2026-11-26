// C main -> asm_main -> re_operation(x0=input, x1=output).
#include "platform.h"
.data
.p2align 4
.globl INPUT, OUTPUT
INPUT: .long 0x12345678, 0x80000000, 0, 0
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
    ldr w8, [x0]
    rev w9, w8                  // reverse four bytes, not all individual bits
    str w9, [x1]
    ror w9, w8, #8
    str w9, [x1, #4]
    ubfx w9, w8, #8, #8         // bit offset 8, field width 8
    str w9, [x1, #8]
    ldr w8, [x0, #4]
    clz w9, w8                  // unlike BSR, zero input has a defined result: 32
    str w9, [x1, #12]
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
