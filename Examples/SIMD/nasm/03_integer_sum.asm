; uint32_t simd_operation(const uint32_t *a, size_t n)
; AVX2: sum eight uint32 lanes, modulo 2^32 (including the scalar tail).
%include "platform.inc"
global ASM_MAIN, OP
section .data align=32
global DATA_A, DATA_N
DATA_N: dq 9                    ; nine elements include a scalar tail
DATA_A: dd 0xffffffff, 17, 34, 0xffffffff, 68, 85, 0xffffffff, 119, 136

section .text
; C main calls this no-argument assembly entry point.
; It passes .data addresses to the reusable operation, then returns its result.
ASM_MAIN:
%ifidn __OUTPUT_FORMAT__, win64
    sub rsp, 40                 ; 32-byte shadow space + align stack for call
%else
    sub rsp, 8                  ; align stack to 16 bytes before call
%endif
    lea A, [rel DATA_A]          ; first argument: address of input array
%ifidn __OUTPUT_FORMAT__, win64
    mov rdx, [rel DATA_N]
%else
    mov rsi, [rel DATA_N]
%endif
    call OP                     ; operation reads the arrays from memory
%ifidn __OUTPUT_FORMAT__, win64
    add rsp, 40
%else
    add rsp, 8
%endif
    ret                         ; scalar result remains in xmm0 or eax

; The driver also calls this function directly for independent test inputs.
OP:
%ifidn __OUTPUT_FORMAT__, win64
    mov r9, rdx  ; Windows: second C argument n -> common COUNT register
%else
    mov rcx, rsi  ; System V: second C argument n -> common COUNT register
%endif
    xor r10d, r10d  ; element index i = 0; writing r10d also clears the upper 32 bits
    mov r11, COUNT  ; retain n in COUNT; r11 will be the full-vector boundary
    and r11, -8  ; round n down to a multiple of 8; never read a partial vector
    vpxor ymm0, ymm0, ymm0  ; start eight independent uint32 partial sums at zero
.vector:
    cmp r10, r11  ; is there a complete group of eight elements left?
    jae .reduce
    vpaddd ymm0, ymm0, [A + r10*4]  ; each of eight uint32 lanes wraps modulo 2^32
    add r10, 8  ; advance by eight elements, not eight bytes
    jmp .vector
.reduce:
    vextracti128 xmm1, ymm0, 1  ; AVX2: copy the upper four integer partial sums
    vpaddd xmm0, xmm0, xmm1  ; combine upper/lower halves using wrapping integer adds
    vphaddd xmm0, xmm0, xmm0  ; pairwise horizontal reduction (repeat to obtain lane-0 total)
    vphaddd xmm0, xmm0, xmm0  ; pairwise horizontal reduction (repeat to obtain lane-0 total)
    vmovd eax, xmm0  ; return uint32 in eax; remaining tail values add to this total
.tail:
    cmp r10, COUNT  ; tail bound uses original n, not the rounded vector boundary
    jae .done
    add eax, [A + r10*4]  ; add one tail integer with the same modulo-2^32 semantics
    inc r10
    jmp .tail
.done:
    vzeroupper  ; clear upper YMM halves before returning to non-AVX C code
    ret
NOTE
