;RDI, RSI, RDX, RCX, R8, R9 (R10) XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for the first floating point arguments.
segment .data
default rel
printInt: db "%d",0
printNewline: db 10,0
printString: db "%s",0

dumpMessage db "RAX: %016lX RBX: %016lX RCX: %016lX RDX: %016lX R8 : %016lX R9 : %016lX", 10,
dl2 db "R10: %016lX R11: %016lX R12: %016lX R13: %016lX R14: %016lX R15: %016lX", 10
dl3 db "RSI: %016lX RDI: %016lX RSP: %016lX RBP: %016lX", 10,0

extern printf

segment .text 
global print_int 
global print_nl
global print_string
global dump_registers
dump_registers:
        ;stack before call + 0x18
        ; return address + 0x10
        push rbp; rbp + 8
        mov rbp, rsp
        push rsi
        push rdi
        push rax
        push rbx
        push rcx
        push rdx
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15
        sub rsp, 0x8
        sub rsp, 0x10
        ; + 28h
        ; + 10h
        push rdi; + 0x8
        push rsi; +0
        mov rsi, rbp
        add rsi, 0x18
        mov [rsp + 0x10], rsi ; rsp
        mov rsi, rbp
        mov rdi, [rsi]
        mov [rsp + 0x18], rdi; rbp
        push r15;     0x38
        push r14;     0x30
        push r13;     0x28
        push r12 ;    0x20
        push r11;     0x18       
        push r10;16 = 0x10
        push r9;8
        mov r9, r8
        mov r8,  rdx
        mov rcx, rcx; same
        mov rdx, rbx
        mov rsi, rax
        mov rdi, dumpMessage
        call printf WRT ..plt
        add rsp, 0x58

        add rsp, 0x8
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rdx
        pop rcx
        pop rbx
        pop rax
        pop rdi
        pop rsi
        pop rbp
        ret


print_int:
	push rax
	push rsi
	push rdi
	mov rsi, rax
	mov rax, 0x0 ; xmm
	mov rdi, printInt
	call printf WRT ..plt
	pop rdi
	pop rsi
	pop rax
	ret
print_nl:
	push rax
	push rsi
	push rdi
	mov rdi, printNewline
	call printf WRT ..plt
	pop rdi
	pop rsi
	pop rax
	ret
print_string:
	push rax
	push rsi
	push rdi
	mov rsi, rax
	mov rdi, printString
	call printf WRT ..plt
	pop rdi
	pop rsi
	pop rax
	ret
