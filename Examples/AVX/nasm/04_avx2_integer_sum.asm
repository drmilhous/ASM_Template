; AVX2: integer SIMD. Sum 1..43 using vpaddd on eight 32-bit lanes,
; then a scalar loop for the leftover elements (43 = 5 * 8 + a tail of 3).
; Uses the ASM_Template I/O library; see platform.inc.
; Build: make 04_avx2_integer_sum   (Linux/macOS)   or   .\quickBuild.ps1 04_avx2_integer_sum   (Windows)

%include "platform.inc"
default rel
global ASM_MAIN

%define COUNT 43                    ; 5 full vectors + a tail of 3

section .data align=64
    arr dd 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30
        dd 31,32,33,34,35,36,37,38,39,40,41,42,43
    s_sum db "sum = ", 0
    s_exp db " (expected 946)", 0

section .text
ASM_MAIN:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8                      ; keep the stack 16-byte aligned

    lea r8, [arr]
    vpxor ymm0, ymm0, ymm0          ; 8 running sums
    xor ecx, ecx                    ; element index
.vec:
    lea edx, [rcx + 8]
    cmp edx, COUNT
    ja .tail                        ; fewer than 8 elements left
    vpaddd ymm0, ymm0, [r8 + rcx*4] ; unaligned load is fine for VEX-encoded memory operands
    add ecx, 8
    jmp .vec

.tail:
    ; reduce 8 lanes to 1
    vextracti128 xmm1, ymm0, 1
    vpaddd xmm0, xmm0, xmm1
    vphaddd xmm0, xmm0, xmm0
    vphaddd xmm0, xmm0, xmm0
    vmovd ebx, xmm0
    vzeroupper
.scalar:
    cmp ecx, COUNT
    jae .done
    add ebx, [r8 + rcx*4]
    inc ecx
    jmp .scalar

.done:
    PRINT_STR s_sum
    PRINT_INT ebx
    PRINT_STR s_exp
    PRINT_NL

    xor eax, eax
    add rsp, 8
    pop rbx
    pop rbp
    ret

GNU_STACK_NOTE
