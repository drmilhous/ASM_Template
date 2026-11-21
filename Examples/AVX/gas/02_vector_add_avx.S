// AVX: the same addition, eight floats at a time (ymm = 256 bits).
// New in AVX: VEX encoding with a separate destination (c = a + b without destroying a).
// GNU as, AT&T syntax. Build: make 02_vector_add_avx
// NASM version of the same program: ../nasm/02_vector_add_avx.asm

    #include "platform.h"

    .globl MAIN

    .data
    .balign 32
a:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0
b:  .float 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0
fmt: .asciz "c[%d] = %.1f\n"

    .bss
    .balign 32
c:  .skip 64

    .text
MAIN:
    push %rbx
    push %r12
    push %r13

    lea a(%rip), %r9
    lea b(%rip), %r10
    lea c(%rip), %r8
    xor %ecx, %ecx
.Lloop:
    vmovaps (%r9,%rcx), %ymm0 // 8 floats (32-byte aligned data)
    vaddps  (%r10,%rcx), %ymm0, %ymm1 // ymm1 = ymm0 + b; ymm0 is kept (3-operand form)
    vmovaps %ymm1, (%r8,%rcx)
    add $32, %ecx
    cmp $64, %ecx // 16 floats * 4 bytes
    jb .Lloop
    vzeroupper // clear the upper halves before calling non-AVX code

    xor %ebx, %ebx
.Lprint:
    lea fmt(%rip), ARG1
    mov %ebx, ARG2D
    lea c(%rip), %rax
    vcvtss2sd (%rax,%rbx,4), %xmm0, %xmm0
    DOUBLE_ARG3
    mov $1, %eax
    CCALL PRINTF
    inc %ebx
    cmp $16, %ebx
    jb .Lprint

    xor %eax, %eax
    pop %r13
    pop %r12
    pop %rbx
    ret

GNU_STACK_NOTE
