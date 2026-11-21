; AVX-512: 16 floats per zmm register, and opmask registers (k1..k7).
; A mask lets one vector instruction handle the "tail" of a loop, so no scalar clean-up loop is needed.
; Here: add arrays of 21 floats = one full vector of 16 + a masked vector of 5.
; Portable: Linux, macOS (Intel) and Windows x64 (see platform.inc). Needs an AVX-512F CPU.
; Build: make 06_avx512_mask   (Linux/macOS)   or   .\quickBuild.ps1 06_avx512_mask   (Windows)

%include "platform.inc"
default rel
global MAIN

%define COUNT 21

section .data align=64
    a   times 32 dd 1.5             ; padding beyond COUNT is never read thanks to the mask
    b   times 32 dd 2.5
    fmt db "sum of c[0..20] = %.1f (expected 84.0)", 10, 0

section .bss align=64
    c   resd 32

section .text
MAIN:
    push rbx

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
    cvtss2sd xmm0, xmm0
    lea ARG1, [fmt]
    DOUBLE_ARG2
    mov eax, 1
    CCALL PRINTF

    xor eax, eax
    pop rbx
    ret

GNU_STACK_NOTE
