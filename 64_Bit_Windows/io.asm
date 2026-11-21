; io.asm for Windows x64 (nasm -f win64): print_int, print_hex, print_nl, print_string.
; Same calling style as the Linux template: the number (or the string address) to print is in RAX.
; Every routine keeps all registers except xmm0-xmm5, flags and the stack below rsp, so you can
; call them anywhere. Each one follows the Microsoft x64 rules for its own call to printf: it
; reserves 32 bytes of shadow space and aligns the stack to 16 bytes itself.
;
; (The previous io.asm here was a copy of the Linux System V one: it passed arguments in rdi/rsi
; and called "printf wrt ..plt", which does not assemble for win64.)
default rel
segment .data
printInt:     db "%d", 0
printHex:     db "%016llX", 0
printNewline: db 10, 0
printString:  db "%s", 0

extern printf

segment .text
global print_int
global print_hex
global print_nl
global print_string

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
        and  rsp, -16           ; 16-byte alignment, whatever the caller did
        sub  rsp, 32            ; shadow space
%endmacro

%macro LIB_LEAVE 0
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

print_int:                      ; prints eax as a signed decimal number
        LIB_ENTER
        mov  edx, eax
        lea  rcx, [printInt]
        call printf
        LIB_LEAVE

print_hex:                      ; prints rax as 16 hex digits
        LIB_ENTER
        mov  rdx, rax
        lea  rcx, [printHex]
        call printf
        LIB_LEAVE

print_nl:                       ; prints a newline
        LIB_ENTER
        lea  rcx, [printNewline]
        call printf
        LIB_LEAVE

print_string:                   ; prints the zero-terminated string at [rax]
        LIB_ENTER
        mov  rdx, rax
        lea  rcx, [printString]
        call printf
        LIB_LEAVE
