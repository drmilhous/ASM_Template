%include "io.inc"
default rel
segment .data 

segment .bss 

segment .text
        global  asm_main
asm_main:
        ; setup routine
        push    ebp      ;prolog
        mov     ebp, esp ;prolog
        ;***************CODE STARTS HERE***************************
	
        
        mov eax, 0 ; success
        ;***************CODE ENDS HERE*****************************
        pop     ebp       ;epilog
        ret               ;return from function 
        ; (pop return address from stack)



        ;***************Function Arguments***************************
                                ; EBP + 0x14 arg 3
                                ; EBP + 0x10 arg 2
                                ; EBP + 0x08 arg 1 
        ;***************Function Arguments***************************