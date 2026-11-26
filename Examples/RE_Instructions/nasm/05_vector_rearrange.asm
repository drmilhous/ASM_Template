; C main -> asm_main -> re_operation(input, output).
; Inputs and writable outputs are in .data; no generated demo values in C.
%include "platform.inc"
global MAIN, OP, INPUT, OUTPUT
section .data align=16
INPUT: dd 1, 2, 1, 4
OUTPUT: times 8 dd 0
section .text
MAIN:
%ifidn __OUTPUT_FORMAT__, win64
    sub rsp, 40                 ; alignment + mandatory shadow space
%else
    sub rsp, 8                  ; 16-byte alignment before the call
%endif
    lea ARG_IN, [rel INPUT]
    lea ARG_OUT, [rel OUTPUT]
    call OP
%ifidn __OUTPUT_FORMAT__, win64
    add rsp, 40
%else
    add rsp, 8
%endif
    ret
OP:
    mov r10, ARG_IN             ; stable pointers despite implicit EAX/EDX uses
    mov r11, ARG_OUT
    ; SSE2 is baseline on x86-64; no AVX feature requirement for this example.
    movdqu xmm0, [r10]          ; load four uint32 elements
    pshufd xmm1, xmm0, 0x1b     ; selectors 3,2,1,0 reverse the element order
    movdqu [r11], xmm1
    pcmpeqd xmm2, xmm2          ; all bits set in each lane
    psrld xmm2, 31              ; each lane now contains integer 1
    pcmpeqd xmm2, xmm0          ; lane == 1 yields 0xffffffff, not integer 1
    movdqu [r11+16], xmm2
    ret
%ifidn __OUTPUT_FORMAT__, elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
