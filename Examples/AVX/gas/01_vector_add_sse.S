// SSE: add two float arrays four floats at a time (xmm = 128 bits)
// GNU as, AT&T syntax: operands are SOURCE first, DESTINATION last.
// Portable: Linux, macOS (Intel) and Windows x64 (see platform.h). Build: make 01_vector_add_sse     Run: ./01_vector_add_sse
// NASM version of the same program: ../nasm/01_vector_add_sse.asm

    #include "platform.h"

    .globl MAIN

    .data
    .balign 16
a:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 // 8 floats = 2 xmm registers
b:  .float 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0
fmt: .asciz "c[%d] = %.1f\n"

    .bss
    .balign 16
c:  .skip 32

    .text
MAIN:
    push %rbx
    push %r12 // keeps the stack 16-byte aligned for printf
    push %r13

    lea a(%rip), %r9 // RIP-relative symbols cannot take an index register,
    lea b(%rip), %r10 // so load the base addresses first
    lea c(%rip), %r8
    xor %ecx, %ecx // byte offset
.Lloop:
    movaps (%r9,%rcx), %xmm0 // load 4 floats (address must be 16-byte aligned)
    addps  (%r10,%rcx), %xmm0 // 4 additions in one instruction
    movaps %xmm0, (%r8,%rcx)
    add $16, %ecx
    cmp $32, %ecx // 8 floats * 4 bytes
    jb .Lloop

    xor %ebx, %ebx // print the result
.Lprint:
    lea fmt(%rip), ARG1
    mov %ebx, ARG2D
    lea c(%rip), %rax
    cvtss2sd (%rax,%rbx,4), %xmm0 // printf takes doubles
    DOUBLE_ARG3
    mov $1, %eax // one vector register argument
    CCALL PRINTF
    inc %ebx
    cmp $8, %ebx
    jb .Lprint

    xor %eax, %eax
    pop %r13
    pop %r12
    pop %rbx
    ret

GNU_STACK_NOTE
