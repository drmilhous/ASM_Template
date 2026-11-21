// Detect which SIMD features this CPU and operating system provide.
// ARM64 counterpart of the x86 CPUID/XGETBV example. NEON (called ASIMD, "Advanced SIMD") is part of
// every ARM64 CPU, so the interesting questions are the optional extras. There is no CPUID that user
// programs may run on every OS, so each OS gives the answer its own way:
//   Linux    getauxval(AT_HWCAP): a word of feature bits that the kernel fills in
//   macOS    sysctlbyname("hw.optional...."): a named integer, missing when the feature is absent
//   Windows  IsProcessorFeaturePresent(PF_...): the feature is a number
// Uses the ASM_Template I/O library; see platform.h.
// Build: make 05_feature_detect    (x86 version: ../nasm/05_cpuid_detect.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 8
f_fp:    .asciz "FP (scalar float) : "
f_asimd: .asciz "ASIMD (NEON)      : "
f_dot:   .asciz "DotProd (sdot)    : "
f_sve:   .asciz "SVE               : "
yes:     .asciz "yes"
no:      .asciz "no"
    .balign 8
labels:  .quad f_fp, f_asimd, f_dot, f_sve
#if defined(__APPLE__)
n_fp:    .asciz "hw.optional.floatingpoint"
n_asimd: .asciz "hw.optional.AdvSIMD"
n_dot:   .asciz "hw.optional.arm.FEAT_DotProd"
n_sve:   .asciz "hw.optional.arm.FEAT_SVE"
    .balign 8
names:   .quad n_fp, n_asimd, n_dot, n_sve
#elif defined(__linux__)
// bit numbers in AT_HWCAP: HWCAP_FP = 0, HWCAP_ASIMD = 1, HWCAP_ASIMDDP = 20, HWCAP_SVE = 22
bits:    .word 0, 1, 20, 22
#else
// PF_ARM_V8_INSTRUCTIONS_AVAILABLE 29, PF_ARM_NEON_INSTRUCTIONS_AVAILABLE 19,
// PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE 43, PF_ARM_SVE_INSTRUCTIONS_AVAILABLE 46
ids:     .word 29, 19, 43, 46
#endif

    .text
    .balign 4
// has_feature(w0 = 0..3) -> w0 = 1 if present, else 0
has_feature:
#if defined(__APPLE__)
    stp  x29, x30, [sp, #-48]!
    mov  x29, sp
    ADDR x1, names
    ldr  x0, [x1, w0, uxtw #3]      // name of the sysctl
    mov  w2, #0
    str  w2, [sp, #16]              // value = 0
    mov  x2, #4
    str  x2, [sp, #24]              // length = 4
    add  x1, sp, #16                // &value
    add  x2, sp, #24                // &length
    mov  x3, #0
    mov  x4, #0
    bl   _sysctlbyname              // returns nonzero when the name does not exist
    cbnz w0, 1f
    ldr  w0, [sp, #16]              // value 1 = present
    cmp  w0, #0
    cset w0, ne
    b    2f
1:  mov  w0, #0
2:  ldp  x29, x30, [sp], #48
    ret
#elif defined(__linux__)
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]
    mov  w19, w0
    mov  x0, #16                    // AT_HWCAP
    bl   getauxval
    ADDR x1, bits
    ldr  w1, [x1, w19, uxtw #2]     // which bit
    lsr  x0, x0, x1
    and  w0, w0, #1
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret
#else
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    ADDR x1, ids
    ldr  w0, [x1, w0, uxtw #2]      // PF_ constant
    bl   IsProcessorFeaturePresent
    cmp  w0, #0
    cset w0, ne
    ldp  x29, x30, [sp], #16
    ret
#endif

ASM_MAIN:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]

    mov  w19, #0                    // feature number 0..3
1:  ADDR x1, labels
    ldr  x0, [x1, w19, uxtw #3]     // its label string
    bl   L_PRINT_STR
    mov  w0, w19
    bl   has_feature
    cbz  w0, 2f
    PRINT_STR yes
    b    3f
2:  PRINT_STR no
3:  PRINT_NL
    add  w19, w19, #1
    cmp  w19, #4
    b.lo 1b

    mov  w0, #0
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

GNU_STACK_NOTE
