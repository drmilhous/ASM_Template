// C main -> asm_main -> re_operation(x0=input, x1=output).
#include "platform.h"
.data
.p2align 4
.globl INPUT, OUTPUT
INPUT: .long 41, 0, 0, 0
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
1:
    ldaxr w8, [x0]              // acquire load; establish exclusive reservation
    add w9, w8, #1              // candidate new counter, modulo 2^32
    stlxr w10, w9, [x0]         // release store: status 0 success, nonzero retry
    cbnz w10, 1b                // reservation loss is not a bad-password check
    str w8, [x1]                // old value from the successful attempt
    str w9, [x1, #4]            // value written by this increment
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
