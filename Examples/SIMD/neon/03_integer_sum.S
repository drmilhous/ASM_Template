// uint32_t simd_operation(const uint32_t *a, size_t n)
// x0=a, x1=n; result w0. Unsigned wrapping sum, same contract as AVX2.
#include "platform.h"
.data
.p2align 4
.globl DATA_A, DATA_N
DATA_N: .quad 9                 // element count, not byte count
DATA_A: .long 0xffffffff, 17, 34, 0xffffffff, 68, 85, 0xffffffff, 119, 136

.text
.p2align 2
.globl ASM_MAIN, OP
// C main -> asm_main -> simd_operation. BL overwrites LR, so save it.
ASM_MAIN:
    stp x29, x30, [sp, #-16]!    // save frame pointer/LR; keep SP aligned
    mov x29, sp
    ADDRESS x0, DATA_A          // address of first input in .data
    ADDRESS x1, DATA_N
    ldr x1, [x1]                // load count from memory
    bl OP                       // pass pointers/count through the ARM64 ABI
    ldp x29, x30, [sp], #16
    ret                         // scalar return stays in s0 or w0

// Leaf operation: caller supplies pointers, so tests can use other arrays.
OP:
    movi v0.4s, #0  // clear four 32-bit accumulation lanes
    cmp x1, #4  // integer sum: x1 is the remaining number of elements
    b.lo 2f  // fewer than four elements: jump forward to reduction/tail
1:
    ld1 {v1.4s}, [x0], #16  // load four input elements, then advance the pointer
    add v0.4s, v0.4s, v1.4s  // four wrapping uint32 additions, not floating-point adds
    sub x1, x1, #4  // account for the four elements just processed
    cmp x1, #4  // integer sum: x1 is the remaining number of elements
    b.hs 1b  // at least four remain: branch backward to the vector loop
2:
    addv s0, v0.4s  // reduce all four integer lanes to one 32-bit bit pattern
    fmov w2, s0  // bitwise register transfer; this is NOT a float-to-int conversion
    cbz x1, 4f  // zero remainder: skip all scalar memory accesses
3:
    ldr w3, [x0], #4  // load one remaining uint32, advancing by four bytes
    add w2, w2, w3  // tail uses the same 32-bit wrapping addition
    subs x1, x1, #1  // consume one tail element and set flags for the branch
    b.ne 3b
4:
    mov w0, w2  // ARM64 C ABI returns uint32 in w0
    ret
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
