// SSE: add two float arrays four floats at a time (xmm = 128 bits)
// GNU as, AT&T syntax: operands are SOURCE first, DESTINATION last.
// Uses the ASM_Template I/O library (print_int, print_string, print_nl); see platform.h.
// Build: make 01_vector_add_sse    (NASM version of the same program: ../nasm/01_vector_add_sse.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
    .balign 64
a:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0     // 8 floats = 2 xmm registers
b:  .float 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0
s_open:  .asciz "c["
s_close: .asciz "] = "

    .bss
    .balign 64
c:  .skip 32

    .text
ASM_MAIN:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12                       // rbp + two pushes keep the stack 16-byte aligned for calls

    lea a(%rip), %r8                // RIP-relative symbols cannot take an index register,
    lea b(%rip), %r9                // so load the base addresses first
    lea c(%rip), %r12
    xor %ecx, %ecx                  // byte offset
.Lloop:
    movaps (%r8,%rcx), %xmm0        // load 4 floats (address must be 16-byte aligned)
    addps  (%r9,%rcx), %xmm0        // 4 additions in one instruction
    movaps %xmm0, (%r12,%rcx)
    add $16, %ecx
    cmp $32, %ecx                   // 8 floats * 4 bytes
    jb .Lloop

    xor %ebx, %ebx                  // print c[i] = value
.Lprint:
    PRINT_STR s_open
    PRINT_INT %ebx
    PRINT_STR s_close
    cvtss2sd (%r12,%rbx,4), %xmm0   // float -> double for print_float
    PRINT_FLOAT
    PRINT_NL
    inc %ebx
    cmp $8, %ebx
    jb .Lprint

    xor %eax, %eax
    pop %r12
    pop %rbx
    pop %rbp
    ret

GNU_STACK_NOTE
