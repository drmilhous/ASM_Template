// C main -> asm_main -> re_operation(x0=input, x1=output).
#include "platform.h"
.data
.p2align 4
.globl INPUT, OUTPUT
INPUT: .long 123, 0xffffffff, 0, 1
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
    movz w9, #0xcccd
    movk w9, #0xcccc, lsl #16   // construct 0xcccccccd in two pieces
    umull x10, w8, w9           // unsigned full-width product
    lsr x10, x10, #35           // unsigned division by constant 10
    str w10, [x1]
    add w9, w8, w8, lsl #1     // 3*x without loading memory
    add w9, w9, #5
    str w9, [x1, #4]
    ldr w8, [x0, #4]
    ldr w9, [x0, #8]
    ldr w10, [x0, #12]
    adds w8, w8, w10           // low-half sum sets carry
    adc w9, w9, wzr            // propagate into high half
    stp w8, w9, [x1, #8]
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
