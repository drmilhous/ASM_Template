// void simd_operation(const float *a, const float *b, float *out, size_t n)
// ARM64 ABI: x0=a, x1=b, x2=out, x3=n. Only volatile registers are used.
#include "platform.h"
.data
.p2align 4
.globl DATA_A, DATA_N
DATA_N: .quad 9                 // element count, not byte count
DATA_A: .float -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5
.globl DATA_B
DATA_B: .float -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, -1.5, -1.0
.globl DATA_OUT
DATA_OUT: .zero 36              // nine floats, writable output

.text
.p2align 2
.globl ASM_MAIN, OP
// C main -> asm_main -> simd_operation. BL overwrites LR, so save it.
ASM_MAIN:
    stp x29, x30, [sp, #-16]!    // save frame pointer/LR; keep SP aligned
    mov x29, sp
    ADDRESS x0, DATA_A          // address of first input in .data
    ADDRESS x1, DATA_B
    ADDRESS x2, DATA_OUT
    ADDRESS x3, DATA_N
    ldr x3, [x3]                // load count from memory
    bl OP                       // pass pointers/count through the ARM64 ABI
    ldp x29, x30, [sp], #16
    ret                         // scalar return stays in s0 or w0

// Leaf operation: caller supplies pointers, so tests can use other arrays.
OP:
    cmp x3, #4  // vector add: x3 is the remaining number of elements
    b.lo 2f  // fewer than four elements: jump forward to reduction/tail
1:
    ldr q0, [x0], #16  // Q0 is all 128 bits of V0: load four floats, advance by 16 bytes
    ldr q1, [x1], #16  // load four b floats, then advance b by 16 bytes
    fadd v2.4s, v0.4s, v1.4s  // four independent float additions
    str q2, [x2], #16  // store four results, then advance output by 16 bytes
    sub x3, x3, #4  // account for the four elements just processed
    cmp x3, #4  // vector add: x3 is the remaining number of elements
    b.hs 1b  // at least four remain: branch backward to the vector loop
2:
    cbz x3, 4f  // zero remainder: skip all scalar memory accesses
3:
    ldr s0, [x0], #4  // load one float for the tail; advance by one element
    ldr s1, [x1], #4  // load one remaining b float
    fadd s2, s0, s1
    str s2, [x2], #4  // write exactly one tail result
    subs x3, x3, #1  // consume one tail element and set flags for the branch
    b.ne 3b
4:
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
