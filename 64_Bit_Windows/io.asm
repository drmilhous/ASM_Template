; io.asm for Windows x64 (nasm -f win64).
;   print_int     prints eax as a signed decimal number
;   print_hex     prints rax as 16 hex digits
;   print_nl      prints a newline
;   print_string  prints the zero-terminated string at [rax]
;   print_float   prints the double in xmm0 (printf "%f")
;   dump_registers prints all general registers (RAX..R15, RSP, RBP) in hex
; Same calling style as the Linux template: the number (or the string address) to print is in RAX
; (the double in XMM0). Every routine keeps all the general registers and xmm0 (the flags change),
; so you can call them anywhere. Each one follows the
; Microsoft x64 rules for its own call to printf: it reserves 32 bytes of shadow space and aligns
; the stack to 16 bytes itself. %llX is used for 64-bit hex because %lX is only 32 bits on Windows.
;
; (The previous io.asm here was a copy of the Linux System V one: it passed arguments in rdi/rsi
; and called "printf wrt ..plt", which does not assemble for win64.)
default rel
segment .data
printInt:     db "%d", 0
printHex:     db "%016llX", 0
printNewline: db 10, 0
printString:  db "%s", 0
printFloat:   db "%f", 0

dumpLine1: db "RAX: %016llX RBX: %016llX RCX: %016llX RDX: %016llX R8 : %016llX R9 : %016llX", 10, 0
dumpLine2: db "R10: %016llX R11: %016llX R12: %016llX R13: %016llX R14: %016llX R15: %016llX", 10, 0
dumpLine3: db "RSI: %016llX RDI: %016llX RSP: %016llX RBP: %016llX", 10, 0

extern printf

segment .text
global print_int
global print_hex
global print_nl
global print_string
global print_float
global dump_registers

; Save the registers printf may change and line up the stack. Uses rbp as the frame pointer.
%macro LIB_ENTER 0
        push rbp
        mov  rbp, rsp
        push rax
        push rcx
        push rdx
        push r8
        push r9
        push r10
        push r11                ; seven registers = 56 bytes below rbp
        sub  rsp, 16
        movups [rsp], xmm0      ; keep xmm0 for the caller (printf changes it)
        and  rsp, -16           ; 16-byte alignment, whatever the caller did
        sub  rsp, 32            ; shadow space
%endmacro

%macro LIB_LEAVE 0
        movups xmm0, [rbp - 72]
        lea  rsp, [rbp - 56]
        pop  r11
        pop  r10
        pop  r9
        pop  r8
        pop  rdx
        pop  rcx
        pop  rax
        pop  rbp
        ret
%endmacro

print_int:
        LIB_ENTER
        mov  edx, eax
        lea  rcx, [printInt]
        call printf
        LIB_LEAVE

print_hex:
        LIB_ENTER
        mov  rdx, rax
        lea  rcx, [printHex]
        call printf
        LIB_LEAVE

print_nl:
        LIB_ENTER
        lea  rcx, [printNewline]
        call printf
        LIB_LEAVE

print_string:
        LIB_ENTER
        mov  rdx, rax
        lea  rcx, [printString]
        call printf
        LIB_LEAVE

print_float:
        LIB_ENTER
        movq rdx, xmm0          ; a double in a variadic call travels in the xmm AND the integer register
        movapd xmm1, xmm0
        lea  rcx, [printFloat]
        call printf
        LIB_LEAVE

dump_registers:
        push rbp
        mov  rbp, rsp
        push rax                ; [rbp-8]
        push rbx                ; [rbp-16]
        push rcx                ; [rbp-24]
        push rdx                ; [rbp-32]
        push rsi                ; [rbp-40]
        push rdi                ; [rbp-48]
        push r8                 ; [rbp-56]
        push r9                 ; [rbp-64]
        push r10                ; [rbp-72]
        push r11                ; [rbp-80]
        push r12                ; [rbp-88]
        push r13                ; [rbp-96]
        push r14                ; [rbp-104]
        push r15                ; [rbp-112]
        sub  rsp, 16
        movups [rsp], xmm0
        and  rsp, -16
        sub  rsp, 64            ; 32 bytes of shadow space + room for 3 stack arguments (+ padding)

        lea  rcx, [dumpLine1]   ; RAX RBX RCX RDX R8 R9: the first three go in registers
        mov  rdx, [rbp - 8]
        mov  r8,  [rbp - 16]
        mov  r9,  [rbp - 24]
        mov  rax, [rbp - 32]    ; the rest go on the stack, above the shadow space
        mov  [rsp + 32], rax
        mov  rax, [rbp - 56]
        mov  [rsp + 40], rax
        mov  rax, [rbp - 64]
        mov  [rsp + 48], rax
        call printf

        lea  rcx, [dumpLine2]   ; R10 R11 R12 R13 R14 R15
        mov  rdx, [rbp - 72]
        mov  r8,  [rbp - 80]
        mov  r9,  [rbp - 88]
        mov  rax, [rbp - 96]
        mov  [rsp + 32], rax
        mov  rax, [rbp - 104]
        mov  [rsp + 40], rax
        mov  rax, [rbp - 112]
        mov  [rsp + 48], rax
        call printf

        lea  rcx, [dumpLine3]   ; RSI RDI RSP RBP
        mov  rdx, [rbp - 40]
        mov  r8,  [rbp - 48]
        lea  r9,  [rbp + 16]    ; rsp as it was before the call to dump_registers
        mov  rax, [rbp]         ; the caller's rbp
        mov  [rsp + 32], rax
        call printf

        movups xmm0, [rbp - 128]
        lea  rsp, [rbp - 112]
        pop  r15
        pop  r14
        pop  r13
        pop  r12
        pop  r11
        pop  r10
        pop  r9
        pop  r8
        pop  rdi
        pop  rsi
        pop  rdx
        pop  rcx
        pop  rbx
        pop  rax
        pop  rbp
        ret
