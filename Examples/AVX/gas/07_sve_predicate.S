// SVE: scalable vectors and predicate registers. A "WHILELT" predicate switches on the lanes that are
// still inside the array, so the same loop handles any array length and any hardware vector length
// (128 to 2048 bits) with no tail code, which is what AVX-512 opmasks do for the x86 example.
// Needs an SVE CPU: Linux on a Graviton 3/4, Neoverse V1/V2, A64FX ... (not Apple M-series or the
// current Windows ARM laptops: the program checks first and says so).
// Uses the ASM_Template I/O library; see platform.h.
// Build: make 07_sve_predicate    (x86 version: ../nasm/06_avx512_mask.asm)

#include "platform.h"

    .arch armv8-a+sve
    .globl ASM_MAIN
    .set COUNT, 21

    .data
    .balign 16
a:  .rept 24
    .float 1.5
    .endr
b:  .rept 24
    .float 2.5
    .endr
s_sum: .asciz "sum of c[0..20] = "
s_exp: .asciz " (expected 84.0)"
s_vl:  .asciz "vector length in floats: "
s_none: .asciz "SVE is not available here (see 05_feature_detect)"
    .balign 16
c:  .space 96

    .text
    .balign 4
ASM_MAIN:
    stp  x29, x30, [sp, #-32]!      // [sp, #16] = spare slot for the result
    mov  x29, sp
    str  x19, [sp, #24]

#if defined(__linux__)
    mov  x0, #16                    // AT_HWCAP: bit 22 = SVE
    bl   getauxval
    tst  x0, #(1 << 22)
    b.eq 9f
    ADDR x9,  a
    ADDR x10, b
    ADDR x11, c
    mov  x12, #0                    // element index
    mov  x13, #COUNT
    whilelt p0.s, x12, x13          // lanes whose index is below COUNT
1:  ld1w {z0.s}, p0/z, [x9, x12, lsl #2]    // inactive lanes are zeroed and never read (no fault)
    ld1w {z1.s}, p0/z, [x10, x12, lsl #2]
    fadd z2.s, z0.s, z1.s
    st1w {z2.s}, p0, [x11, x12, lsl #2]     // inactive lanes are not written
    incw x12                        // x12 += number of 32-bit lanes in a vector (hardware dependent)
    whilelt p0.s, x12, x13
    b.mi 1b                         // the first predicate lane is set: more work to do

    ADDR x11, c                     // sum c[0..20] with scalar code
    movi d0, #0
    mov  w14, #COUNT
2:  ldr  s1, [x11], #4
    fadd s0, s0, s1
    subs w14, w14, #1
    b.ne 2b
    fcvt d0, s0
    str  d0, [sp, #16]

    PRINT_STR s_vl
    cntw x0                         // lanes per vector on this CPU
    PRINT_INT w0
    PRINT_NL
    PRINT_STR s_sum
    ldr  d0, [sp, #16]
    PRINT_FLOAT
    PRINT_STR s_exp
    PRINT_NL
    b    10f
9:
#endif
    PRINT_STR s_none
    PRINT_NL
10: mov  w0, #0
    ldr  x19, [sp, #24]
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
