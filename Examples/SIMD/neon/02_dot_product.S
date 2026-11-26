// float simd_operation(const float *a, const float *b, size_t n)
// x0=a, x1=b, x2=n; result s0. Four independent accumulation lanes.
#include "platform.h"
.data
.p2align 4
.globl DATA_A, DATA_N
DATA_N: .quad 9                 // element count, not byte count
DATA_A: .float -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5
.globl DATA_B
DATA_B: .float -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, -1.5, -1.0

.text
.p2align 2
.globl ASM_MAIN, OP
// C main -> asm_main -> simd_operation. BL overwrites LR, so save it.
ASM_MAIN:
    stp x29, x30, [sp, #-16]!    // save frame pointer/LR; keep SP aligned
    mov x29, sp
    ADDRESS x0, DATA_A          // address of first input in .data
    ADDRESS x1, DATA_B
    ADDRESS x2, DATA_N
    ldr x2, [x2]                // load count from memory
    bl OP                       // pass pointers/count through the ARM64 ABI
    ldp x29, x30, [sp], #16
    ret                         // scalar return stays in s0 or w0

// Leaf operation: caller supplies pointers, so tests can use other arrays.
OP:
    movi v0.4s, #0  // clear four 32-bit accumulation lanes
    cmp x2, #4  // dot product: x2 is the remaining number of elements
    b.lo 2f  // fewer than four elements: jump forward to reduction/tail
1:
    ld1 {v1.4s}, [x0], #16  // load four input elements, then advance the pointer
    ld1 {v2.4s}, [x1], #16  // load four b floats for the dot product
    fmul v1.4s, v1.4s, v2.4s  // four products; no fused multiply-add rounding here
    fadd v0.4s, v0.4s, v1.4s  // accumulate each product in its corresponding lane
    sub x2, x2, #4  // account for the four elements just processed
    cmp x2, #4  // dot product: x2 is the remaining number of elements
    b.hs 1b  // at least four remain: branch backward to the vector loop
2:
    faddp v0.4s, v0.4s, v0.4s  // pairwise sums: [lane0+lane1, lane2+lane3, repeated pair]
    faddp s0, v0.2s  // combine the first two partial sums into scalar s0
    cbz x2, 4f  // zero remainder: skip all scalar memory accesses
3:
    ldr s1, [x0], #4  // load one remaining a float
    ldr s2, [x1], #4  // load one remaining b float for the dot product
    fmul s1, s1, s2
    fadd s0, s0, s1
    subs x2, x2, #1  // consume one tail element and set flags for the branch
    b.ne 3b
4:
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
