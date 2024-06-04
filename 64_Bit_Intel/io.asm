;RDI, RSI, RDX, RCX, R8, R9 (R10) XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for the first floating point arguments.
segment .data
default rel
printInt: db "%d",0
printNewline: db 10,0
printString: db "%s",0
hex_format: db "%*X", 0 
space: db " ", 0


dumpMessage db "RAX: %016lX RBX: %016lX RCX: %016lX RDX: %016lX R8 : %016lX R9 : %016lX", 10,
dl2 db "R10: %016lX R11: %016lX R12: %016lX R13: %016lX R14: %016lX R15: %016lX", 10
dl3 db "RSI: %016lX RDI: %016lX RSP: %016lX RBP: %016lX", 10,0

extern printf
extern putchar

segment .text 
global print_int 
global print_nl
global print_string
global dump_registers
global print64Hex
global printBits
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
        lea rdi, [dumpMessage]
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
	lea rdi, [printInt]
	call printf WRT ..plt
	pop rdi
	pop rsi
	pop rax
	ret
print_nl:
	push rax
	push rsi
	push rdi
	lea rdi, [printNewline]
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
	lea rdi, [printString]
	call printf WRT ..plt
	pop rdi
	pop rsi
	pop rax
	ret

printBits:
        push rbp ; prolouge
        mov rbp, rsp
        push rsi; save my used registers
        push rdi
        push r12
        push r13
        push r14
        push rdx
        mov r12, 0x8000000000000000; initial bit mask
        ;0x1000000000000000
        ;0x0100000000000000
        ;  r12 000000010000000000000
        ; rsi  101010100101010100101
        ; rsi  000000000000000000000
        ;  r12 000000100000000000000
        ; rsi  101010100101010100101
        ; rsi  000000100000000000000

        mov r13, rdi ; mov arg 1 to r13 
        mov r14, 4; counter

        top:    cmp r12, 0
                jz done
                        mov rsi, r13 ; copy to here, so don't destroy
                        and rsi, r12; setting rdx to 0 or 1 
                        mov rax, '0'
                        cmovz rdi, rax
                        mov rax, '1'
                        cmovnz rdi, rax
                        call putchar  wrt ..plt
                        shr r12, 1
                        sub r14, 1 ; if counter == 0
                        cmp r14,0
                        jnz top
                        mov rdi, ' '
                        call putchar wrt ..plt
                        mov r14, 4 ; reset counter
                        jmp top
        done:
        call print_nl
        mov rsi, 4
        mov rdi,r13
        call print64Hex
        pop rdx
        pop r14
        pop r13
        pop r12
        pop rdi
        pop rsi
        pop rbp
        ret
print64Hex:
        push rbp
        mov rbp, rsp
        mov r15, rdi; R15 has the value
        mov r13,0xf000000000000000
        mov rcx, 64; initial counter
        hex_test:
                sub rcx, 4; shift counter
                mov r14, r13 ; get the mask 
                and r14, r15
                shr r14, cl
                mov rdx, r14
                ; mov rsi, 1
                ; mov rsi, r14
                push rcx
                push rsi; argument gives the number of spaces
                lea rdi, hex_format
                call printf wrt ..plt
                lea rdi, space
                call printf wrt ..plt
                pop rsi
                pop rcx
                shr r13, 4
                cmp r13, 0
                jz hex_done        
                jmp hex_test
        hex_done:
        call print_nl
        mov rsp, rbp
        pop rbp
        ret