;RDI, RSI, RDX, RCX, R8, R9 (R10) XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for the first floating point arguments.
segment .data
printInt: db "%d",0
printNewline: db 10,0
printString: db "%s",0
dump_regs_string: db "RAX =0x%16X", 10,0
extern printf

segment .text 
global print_int 
global print_nl
global print_string
global dump_regs
