// AVX2: integer SIMD. Sum 1..43 using vpaddd on eight 32-bit lanes,
// then a scalar loop for the leftover elements (43 = 5 * 8 + a tail of 3).
// GNU as, AT&T syntax. Uses the ASM_Template I/O library; see platform.h.
// Build: make 04_avx2_integer_sum    (NASM version of the same program: ../nasm/04_avx2_integer_sum.asm)

#include "platform.h"

    .globl ASM_MAIN
    .set COUNT, 43                      // 5 full vectors + a tail of 3

    .data
    .balign 64
arr: .long 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30
     .long 31,32,33,34,35,36,37,38,39,40,41,42,43
s_sum: .asciz "sum = "
s_exp: .asciz " (expected 946)"

    .text
ASM_MAIN:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    sub $8, %rsp                        // keep the stack 16-byte aligned

    lea arr(%rip), %r8
    vpxor %ymm0, %ymm0, %ymm0           // 8 running sums
    xor %ecx, %ecx                      // element index
.Lvec:
    lea 8(%rcx), %edx
    cmp $COUNT, %edx
    ja .Ltail                           // fewer than 8 elements left
    vpaddd (%r8,%rcx,4), %ymm0, %ymm0   // unaligned load is fine for VEX-encoded memory operands
    add $8, %ecx
    jmp .Lvec

.Ltail:
    // reduce 8 lanes to 1
    vextracti128 $1, %ymm0, %xmm1
    vpaddd %xmm1, %xmm0, %xmm0
    vphaddd %xmm0, %xmm0, %xmm0
    vphaddd %xmm0, %xmm0, %xmm0
    vmovd %xmm0, %ebx
    vzeroupper
.Lscalar:
    cmp $COUNT, %ecx
    jae .Ldone
    add (%r8,%rcx,4), %ebx
    inc %ecx
    jmp .Lscalar

.Ldone:
    PRINT_STR s_sum
    PRINT_INT %ebx
    PRINT_STR s_exp
    PRINT_NL

    xor %eax, %eax
    add $8, %rsp
    pop %rbx
    pop %rbp
    ret

GNU_STACK_NOTE
