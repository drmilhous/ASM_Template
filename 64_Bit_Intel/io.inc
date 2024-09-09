extern print_int
extern print_nl
extern print_string
extern dump_regs
extern print64Hex
extern printBits
extern read_int
extern print_hex


%macro prolouge 1
%push context_%1      ; save the current context 
        %stacksize flat64    ; use rpb 
        %assign %$localsize 0; init localsize
        push rbp
        mov rbp, rsp
%endmacro

%macro local_space 0
        sub rsp, %$localsize   ; see text for explanation 
%endmacro

%macro epilogue 0
        mov rsp, rbp
        pop rbp
        ret 
        %pop;restore original context
%endmacro