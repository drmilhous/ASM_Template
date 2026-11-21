; SSE: add two float arrays four floats at a time (xmm = 128 bits)
; Uses the ASM_Template I/O library (print_int, print_string, print_nl); see platform.inc.
; Build: make 01_vector_add_sse   (Linux/macOS)   or   .\quickBuild.ps1 01_vector_add_sse   (Windows)

%include "platform.inc"
default rel
global ASM_MAIN

section .data align=64
    a   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0     ; 8 floats = 2 xmm registers
    b   dd 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0
    s_open  db "c[", 0
    s_close db "] = ", 0

section .bss align=64
    c   resd 8

section .text
ASM_MAIN:
    push rbp
    mov rbp, rsp
    push rbx
    push r12                        ; rbp + two pushes keep the stack 16-byte aligned for calls

    lea r8,  [a]                    ; a symbol plus an index register cannot be encoded
    lea r9,  [b]                    ; RIP-relative, so load the base addresses first
    lea r12, [c]
    xor ecx, ecx                    ; byte offset
.loop:
    movaps xmm0, [r8 + rcx]         ; load 4 floats (address must be 16-byte aligned)
    addps  xmm0, [r9 + rcx]         ; 4 additions in one instruction
    movaps [r12 + rcx], xmm0
    add ecx, 16
    cmp ecx, 32                     ; 8 floats * 4 bytes
    jb .loop

    xor ebx, ebx                    ; print c[i] = value
.print:
    PRINT_STR s_open
    PRINT_INT ebx
    PRINT_STR s_close
    cvtss2sd xmm0, [r12 + rbx*4]    ; float -> double for print_float
    PRINT_FLOAT
    PRINT_NL
    inc ebx
    cmp ebx, 8
    jb .print

    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret

GNU_STACK_NOTE
