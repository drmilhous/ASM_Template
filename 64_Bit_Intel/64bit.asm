%include "io.inc"
default rel
segment .data 

segment .bss 

segment .text
        global  asm_main
asm_main:
        ; setup routine
        push    rbp      ;prolog
        mov     rbp, rsp ;prolog
        ;***************Function Arguments*************************
                                ; RBP+0x10 arg 7
                                ; R9 arg 6                      
                                ; R8 arg 5
                                ; RCX arg 4
                                ; RDX arg 3
        mov     rsi, 0          ; RSI arg 2
        mov     rdi, 0          ; RDI arg 1 
        ;***************Function Arguments*************************      
        ; sub     rsp, 8 ; has to be 16 byte boundary
	;***************CODE STARTS HERE***************************
	
        
        mov rax, 0 ; success
        ;***************CODE ENDS HERE*****************************
        ; add     rsp, 8 ; has to be 16 byte boundary
        pop     rbp       ;epilog
        ret               ;return from function 
        ; (pop return address from stack)



