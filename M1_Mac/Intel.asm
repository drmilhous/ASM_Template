%include "io.inc"
default rel
segment .data 
hello db "Hello World",10,0
segment .bss 

segment .text
        global  _asm_main
        extern _printf
_asm_main:
        ; setup routine
        push    rbp      ;prolog
        mov     rbp, rsp ;prolog
        ; sub     rsp, 8 ; has to be 16 byte boundary
	;***************CODE STARTS HERE***************************
	
        lea rax, [rel hello]
        call _printf
        mov rax, 0 ; success
        ;***************CODE ENDS HERE*****************************
        ; add     rsp, 8 ; has to be 16 byte boundary
        pop     rbp       ;epilog
        ret               ;return from function 
        ; (pop return address from stack)



        ;***************Function Arguments***************************
                                ; RBP+0x10 arg 7
                                ; R9 arg 6                      
                                ; R8 arg 5
                                ; RCX arg 4
                                ; RDX arg 3
        mov     rsi, 0          ; RSI arg 2
        mov     rdi, 0          ; RDI arg 1 
        ;***************Function Arguments***************************