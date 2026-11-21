// AVX + FMA3: dot product of two 16-float vectors.
// vfmadd231ps does acc += x * y in one instruction (one rounding step).
// The final step adds the eight lanes of the accumulator together ("horizontal add").
// GNU as, AT&T syntax. Build: make 03_dot_product_fma     (needs a CPU with FMA)
// NASM version of the same program: ../nasm/03_dot_product_fma.asm

    #include "platform.h"

    .globl MAIN

    .data
    .balign 32
x:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
y:  .float 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0
fmt: .asciz "dot = %.1f (expected 108.0)\n"

    .text
MAIN:
    push %rbx // align the stack for printf

    lea x(%rip), %r9
    lea y(%rip), %r10
    vxorps %ymm2, %ymm2, %ymm2 // accumulator = 0
    xor %ecx, %ecx
.Lloop:
    vmovaps (%r9,%rcx), %ymm0
    vfmadd231ps (%r10,%rcx), %ymm0, %ymm2 // ymm2 += ymm0 * y[i..i+7]
    add $32, %ecx
    cmp $64, %ecx
    jb .Lloop

    // horizontal sum of the 8 lanes in ymm2
    vextractf128 $1, %ymm2, %xmm1 // upper 4 lanes
    vaddps  %xmm1, %xmm2, %xmm0 // 8 -> 4 partial sums
    vhaddps %xmm0, %xmm0, %xmm0 // 4 -> 2
    vhaddps %xmm0, %xmm0, %xmm0 // 2 -> 1
    vcvtss2sd %xmm0, %xmm0, %xmm0
    vzeroupper

    lea fmt(%rip), ARG1
    DOUBLE_ARG2
    mov $1, %eax
    CCALL PRINTF

    xor %eax, %eax
    pop %rbx
    ret

GNU_STACK_NOTE
