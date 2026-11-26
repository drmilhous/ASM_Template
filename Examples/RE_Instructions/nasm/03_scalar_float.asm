; C main -> asm_main -> re_operation(input, output).
; Inputs and writable outputs are in .data; no generated demo values in C.
%include "platform.inc"
global MAIN, OP, INPUT, OUTPUT
section .data align=16
INPUT: dd 0xc0700000, 0x40100000, 0, 0x7fc00000
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
    ; Input words encode float32 [-3.75, 2.25, 0, quiet NaN].
    movss xmm0, [r10]
    movaps xmm1, xmm0
    addss xmm0, [r10+4]
    movss [r11], xmm0            ; output 0 is a float bit pattern
    cvttss2si eax, [r10]         ; truncate toward zero, not floor
    mov [r11+4], eax
    ucomiss xmm1, [r10+4]
    setb al                     ; CF=1 also for unordered: must exclude NaN
    setnp dl                    ; PF=0 means ordered
    and al, dl
    movzx eax, al
    mov [r11+8], eax
    movss xmm0, [r10+12]
    ucomiss xmm0, xmm0
    setp al                     ; NaN is unordered even against itself
    movzx eax, al
    mov [r11+12], eax
    ret
%ifidn __OUTPUT_FORMAT__, elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
