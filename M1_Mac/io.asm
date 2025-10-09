;RDI, RSI, RDX, RCX, R8, R9 (R10) XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for the first floating point arguments.
segment .data
printInt: db "%d",0
printNewline: db 10,0
printString: db "%s",0
dump_regs_string: db  "RAX: 0x%016lX RBX: 0x%016lX RCX: 0x%016lX RDX: 0x%016lX RSP: 0x%016lX RBP: 0x%016lX RSI: 0x%016lX RDI: 0x%016lX",10, 
dump_regs_string2: db "R8:  0x%016lX R9:  0x%016lX R10: 0x%016lX R11: 0x%016lX R12: 0x%016lX R13: 0x%016lX R14: 0x%016lX R15: 0x%016lX",10,0


extern _printf

segment .text 
global print_int 
global print_nl
global print_string
global dump_regs

print_int:
        ; setup routine
        push    rbp      ;prolog
        mov     rbp, rsp ;prolog
        push    rax
        push    rsi
        ;***************CODE STARTS HERE***************************
        mov     rsi, rdi ; move integer to second argument
        lea     rdi, [rel printInt] ; first argument format string
        xor     rax, rax ; no floating point args
        call       _printf
        ;***************CODE ENDS HERE*****************************
        pop     rsi
        pop     rax
        mov     rsp, rbp  ;epilog
        pop     rbp       ;epilog
        ret               ;return from function 
        ; (pop return address from stack)

print_nl:
        ; setup routine
        push    rbp      ;prolog
        mov     rbp, rsp ;prolog
        push    rax    
        push    rdi

        ;***************CODE STARTS HERE***************************
        lea     rdi, [rel printNewline] ; first argument format string
        xor     rax, rax ; no floating point args
        call       _printf
        ;***************CODE ENDS HERE*****************************
        pop     rdi
        pop     rax
        mov     rsp, rbp  ;epilog
        pop     rbp       ;epilog
        ret               ;return from function

print_string:
        ; setup routine
        push    rbp      ;prolog
        mov     rbp, rsp ;prolog
        push    rax
        push    rsi
        ;***************CODE STARTS HERE***************************
        mov     rsi, rdi ; move string address to second argument
        lea     rdi, [rel printString] ; first argument format string
        xor     rax, rax ; no floating point args
        call       _printf
        ;***************CODE ENDS HERE*****************************
        pop     rsi
        pop     rax
        mov     rsp, rbp  ;epilog
        pop     rbp       ;epilog
        ret               ;return from function 
        ; (pop return address from stack)

dump_regs:
        ; setup routine
        push    rbp      ;prolog
        mov     rbp, rsp ;prolog
    
        ; save all registers
        push    rax; - 0x8
        push    rbx; - 0x10
        push    rcx; - 0x18
        push    rdx; - 0x20
        push    rdi; - 0x28
        push    rsi; - 0x30
        push    r8;  - 0x38
        push    r9;  - 0x40
        push    r10; - 0x48
        push    r11; - 0x50
        push    r12; - 0x58
        push    r13; - 0x60
        push    r14; - 0x68
        push    r15; - 0x70
        ; r15
        push r15 ; do r15 arg 16

        ; r14
        push r14 ; do r14 arg 15

        ; r13
        push r13 ; do r13 arg 14

        ; r12
        push r12 ; do r12 arg 13

        ; r11
        push r11 ; do r11 arg 12

        ; r10
        push r10 ; do r10 arg 11

        ; r9 
        push r9 ; do r9 arg 10        
        
        ; r8
        push r8 ; do r8 arg 9

        ; rdi
        push rdi ; do rdi arg 8
        
        ; rsi
        push rsi

        ; rpb
        mov rax, [rbp]
        push rax
        
        ; rsp
        mov r9,  rbp ; do rsp arg 6
        add r9, 0x10 ; 8 for return address + 8 for old rbp
        

        ; rdx
        mov r8, [rbp - 0x20]; do rdx arg 5

        ; rcx 
        mov rcx, [rbp - 0x18]; do rcx arg 4

        ; rbx
        mov rdx, [rbp - 0x10]; do rbx arg 3

        ; rax
        mov  rsi, [rbp - 0x8] ; do rax arg 2

        lea     rdi, [rel dump_regs_string] ; first argument format string
        xor     rax, rax ; no floating point args

        call       _printf
        add rsp, 0x58


        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     r11
        pop     r10
        pop     r8
        pop     rdi
        pop     rsi
        pop     rdx
        pop     rcx
        pop     rbx
        pop     rax        
        mov rsp, rbp  ;epilog
        pop     rbp
        ret               ;return from function
        ; (pop return address from stack)