; AVX-512: 16 floats per zmm register, and opmask registers (k1..k7).
; A mask lets one vector instruction handle the "tail" of a loop, so no scalar clean-up loop is needed.
; Here: add arrays of 21 floats = one full vector of 16 + a masked vector of 5.
; Needs an AVX-512F CPU. Uses the ASM_Template I/O library; see platform.inc.
; Build: make 06_avx512_mask   (Linux/macOS)   or   .\quickBuild.ps1 06_avx512_mask   (Windows)

%include "platform.inc"
default rel
global ASM_MAIN

%define COUNT 21

section .data align=64
    a   times 32 dd 1.5             ; padding beyond COUNT is never read thanks to the mask
    b   times 32 dd 2.5
    s_sum db "sum of c[0..20] = ", 0
    s_exp db " (expected 84.0)", 0

section .bss align=64
    c   resd 32

section .text
ASM_MAIN:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8                      ; spare 8-byte slot for the result (also keeps the stack aligned)

    lea r8,  [a]
    lea r9,  [b]
    lea r10, [c]
    xor ecx, ecx                    ; element index
.loop:
    mov edx, COUNT
    sub edx, ecx                    ; elements left
    jle .done
    cmp edx, 16
    jb .masked
    vmovups zmm0, [r8 + rcx*4]
    vaddps  zmm0, zmm0, [r9 + rcx*4]
    vmovups [r10 + rcx*4], zmm0
    add ecx, 16
    jmp .loop

.masked:
    mov eax, 1
    shlx eax, eax, edx              ; 1 << left
    dec eax                         ; low "left" bits set
    kmovw k1, eax
    vmovups zmm0{k1}{z}, [r8 + rcx*4]       ; masked-off lanes are zeroed and not read (no fault)
    vaddps  zmm0{k1}{z}, zmm0, [r9 + rcx*4]
    vmovups [r10 + rcx*4]{k1}, zmm0         ; masked store writes only the selected lanes
.done:
    ; sum c[0..20] with scalar code to show the result
    vzeroupper
    xorps xmm0, xmm0
    xor ecx, ecx
.sum:
    addss xmm0, [r10 + rcx*4]
    inc ecx
    cmp ecx, COUNT
    jb .sum
    cvtss2sd xmm0, xmm0             ; float -> double for print_float
    movsd [rsp], xmm0               ; keep it in the spare stack slot across print_string

    PRINT_STR s_sum
    movsd xmm0, [rsp]
    PRINT_FLOAT
    PRINT_STR s_exp
    PRINT_NL

    xor eax, eax
    add rsp, 8
    pop rbx
    pop rbp
    ret

GNU_STACK_NOTE
