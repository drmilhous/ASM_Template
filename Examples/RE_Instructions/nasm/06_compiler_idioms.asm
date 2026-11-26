; C main -> asm_main -> re_operation(input, output).
; Inputs and writable outputs are in .data; no generated demo values in C.
%include "platform.inc"
global MAIN, OP, INPUT, OUTPUT
section .data align=16
INPUT: dd 123, 0xffffffff, 0, 1
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
    mov eax, [r10]
    mov ecx, 0xcccccccd
    mul ecx                     ; unsigned 32x32 -> EDX:EAX (implicit operands)
    shr edx, 3                  ; high product >>3 == floor(input / 10)
    mov [r11], edx
    mov eax, [r10]
    lea eax, [rax+rax*2+5]       ; 3*x+5; NO memory read despite brackets
    mov [r11+4], eax
    mov eax, [r10+4]             ; low half of a two-word integer
    mov edx, [r10+8]             ; high half
    add eax, [r10+12]            ; add to low half and set CF
    adc edx, 0                  ; propagate CF into high half
    mov [r11+8], eax
    mov [r11+12], edx
    ret
%ifidn __OUTPUT_FORMAT__, elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
