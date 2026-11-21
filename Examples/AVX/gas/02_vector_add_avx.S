// AVX: the same addition, eight floats at a time (ymm = 256 bits).
// New in AVX: VEX encoding with a separate destination (c = a + b without destroying a).
// GNU as, AT&T syntax. Uses the ASM_Template I/O library; see platform.h.
// Build: make 02_vector_add_avx    (NASM version of the same program: ../nasm/02_vector_add_avx.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 64
a:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0
b:  .float 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0
s_open:  .asciz "c["
s_close: .asciz "] = "

    .bss
    .balign 64
c:  .skip 64

    .text
ASM_MAIN:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12

    lea a(%rip), %r8
    lea b(%rip), %r9
    lea c(%rip), %r12
    xor %ecx, %ecx
.Lloop:
    vmovaps (%r8,%rcx), %ymm0           // 8 floats (32-byte aligned data)
    vaddps  (%r9,%rcx), %ymm0, %ymm1    // ymm1 = ymm0 + b; ymm0 is kept (3-operand form)
    vmovaps %ymm1, (%r12,%rcx)
    add $32, %ecx
    cmp $64, %ecx                       // 16 floats * 4 bytes
    jb .Lloop
    vzeroupper                          // clear the upper halves before calling non-AVX code

    xor %ebx, %ebx
.Lprint:
    PRINT_STR s_open
    PRINT_INT %ebx
    PRINT_STR s_close
    cvttss2si (%r12,%rbx,4), %eax
    PRINT_INT %eax
    PRINT_NL
    inc %ebx
    cmp $16, %ebx
    jb .Lprint

    xor %eax, %eax
    pop %r12
    pop %rbx
    pop %rbp
    ret

GNU_STACK_NOTE
