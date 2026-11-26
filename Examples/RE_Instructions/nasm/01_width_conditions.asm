; C main -> asm_main -> re_operation(input, output).
; Inputs and writable outputs are in .data; no generated demo values in C.
%include "platform.inc"
global MAIN, OP, INPUT, OUTPUT
section .data align=16
INPUT: dd 0xff, 0xfffffff9, 3, 0
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
    ; Same byte, two interpretations: signed -1 versus unsigned 255.
    movsx eax, byte [r10]
    mov [r11], eax
    movzx eax, byte [r10]
    mov [r11+4], eax
    ; Signed minimum, with no conditional branch.
    mov eax, [r10+4]
    mov ecx, [r10+8]
    cmp eax, ecx
    cmovg eax, ecx
    mov [r11+8], eax
    ; The SAME original inputs compared as unsigned integers.
    mov eax, [r10+4]
    cmp eax, ecx
    setb al
    movzx eax, al
    mov [r11+12], eax
    ret
%ifidn __OUTPUT_FORMAT__, elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
