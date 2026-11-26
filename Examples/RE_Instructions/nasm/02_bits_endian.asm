; C main -> asm_main -> re_operation(input, output).
; Inputs and writable outputs are in .data; no generated demo values in C.
%include "platform.inc"
global MAIN, OP, INPUT, OUTPUT
section .data align=16
INPUT: dd 0x12345678, 0x80000000, 0, 0
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
    bswap eax                   ; 0x12345678 -> 0x78563412
    mov [r11], eax
    mov eax, [r10]
    ror eax, 8                  ; rotation wraps bits; shift would discard them
    mov [r11+4], eax
    mov eax, [r10]
    shr eax, 8
    and eax, 0xff               ; extract bits 8..15
    mov [r11+8], eax
    mov eax, 32                 ; defined answer when input is zero
    mov ecx, [r10+4]
    test ecx, ecx
    jz .count_done
    bsr eax, ecx                ; BSR destination is undefined for zero
    xor eax, 31                 ; highest-set-bit index -> leading zero count
.count_done:
    mov [r11+12], eax
    ret
%ifidn __OUTPUT_FORMAT__, elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
