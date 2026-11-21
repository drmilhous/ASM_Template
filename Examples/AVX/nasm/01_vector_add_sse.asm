; SSE: add two float arrays four floats at a time (xmm = 128 bits)
; Portable: Linux, macOS (Intel) and Windows x64 (see platform.inc).
; Build: make 01_vector_add_sse   (Linux/macOS)   or   .\quickBuild.ps1 01_vector_add_sse   (Windows)

%include "platform.inc"
default rel
global MAIN

section .data align=64
    a   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0     ; 8 floats = 2 xmm registers
    b   dd 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0
    fmt db "c[%d] = %.1f", 10, 0

section .bss align=64
    c   resd 8

section .text
MAIN:
    push rbx
    push r12                        ; three pushes keep the stack 16-byte aligned for calls
    push r13

    lea r8,  [a]                    ; a symbol plus an index register cannot be encoded
    lea r9,  [b]                    ; RIP-relative, so load the base addresses first
    lea r10, [c]
    xor ecx, ecx                    ; byte offset
.loop:
    movaps xmm0, [r8 + rcx]         ; load 4 floats (address must be 16-byte aligned)
    addps  xmm0, [r9 + rcx]         ; 4 additions in one instruction
    movaps [r10 + rcx], xmm0
    add ecx, 16
    cmp ecx, 32                     ; 8 floats * 4 bytes
    jb .loop

    xor ebx, ebx                    ; print the result
.print:
    lea ARG1, [fmt]
    mov ARG2D, ebx
    lea rax, [c]
    cvtss2sd xmm0, [rax + rbx*4]    ; printf takes doubles
    DOUBLE_ARG3
    mov eax, 1                      ; System V: one vector register argument
    CCALL PRINTF
    inc ebx
    cmp ebx, 8
    jb .print

    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

GNU_STACK_NOTE
