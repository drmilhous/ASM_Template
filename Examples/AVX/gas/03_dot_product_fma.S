// AVX + FMA3: dot product of two 16-float vectors.
// vfmadd231ps does acc += x * y in one instruction (one rounding step).
// The final step adds the eight lanes of the accumulator together ("horizontal add").
// GNU as, AT&T syntax. Needs a CPU with FMA. Uses the ASM_Template I/O library; see platform.h.
// Build: make 03_dot_product_fma    (NASM version of the same program: ../nasm/03_dot_product_fma.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 64
x:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
y:  .float 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0
s_dot: .asciz "dot = "
s_exp: .asciz " (expected 108.0)"

    .text
ASM_MAIN:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    sub $8, %rsp                        // spare 8-byte slot for the result (also keeps the stack aligned)

    lea x(%rip), %r8
    lea y(%rip), %r9
    vxorps %ymm2, %ymm2, %ymm2          // accumulator = 0
    xor %ecx, %ecx
.Lloop:
    vmovaps (%r8,%rcx), %ymm0
    vfmadd231ps (%r9,%rcx), %ymm0, %ymm2    // ymm2 += ymm0 * y[i..i+7]
    add $32, %ecx
    cmp $64, %ecx
    jb .Lloop

    // horizontal sum of the 8 lanes in ymm2
    vextractf128 $1, %ymm2, %xmm1       // upper 4 lanes
    vaddps  %xmm1, %xmm2, %xmm0         // 8 -> 4 partial sums
    vhaddps %xmm0, %xmm0, %xmm0         // 4 -> 2
    vhaddps %xmm0, %xmm0, %xmm0         // 2 -> 1
    vcvtss2sd %xmm0, %xmm0, %xmm0       // float -> double for print_float
    vmovsd %xmm0, (%rsp)                // keep it in the spare stack slot across print_string
    vzeroupper

    PRINT_STR s_dot
    vmovsd (%rsp), %xmm0
    PRINT_FLOAT
    PRINT_STR s_exp
    PRINT_NL

    xor %eax, %eax
    add $8, %rsp
    pop %rbx
    pop %rbp
    ret

GNU_STACK_NOTE
