; float simd_operation(const float *a, const float *b, size_t n)
; AVX multiply + add, deliberately not FMA: compare lane grouping with NEON.
%include "platform.inc"
global ASM_MAIN, OP
section .data align=32
global DATA_A, DATA_N
DATA_N: dq 9                    ; nine elements include a scalar tail
DATA_A: dd -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5
global DATA_B
DATA_B: dd -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, -1.5, -1.0

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
    lea B, [rel DATA_B]          ; second argument: address of b
%ifidn __OUTPUT_FORMAT__, win64
    mov r8, [rel DATA_N]
%else
    mov rdx, [rel DATA_N]
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
    mov r9, r8  ; Windows: third C argument n -> common COUNT register
%else
    mov rcx, rdx  ; System V: third C argument n -> common COUNT register
%endif
    xor r10d, r10d  ; element index i = 0; writing r10d also clears the upper 32 bits
    mov r11, COUNT  ; retain n in COUNT; r11 will be the full-vector boundary
    and r11, -8  ; round n down to a multiple of 8; never read a partial vector
    vxorps ymm0, ymm0, ymm0  ; start eight independent floating-point partial sums at zero
.vector:
    cmp r10, r11  ; is there a complete group of eight elements left?
    jae .reduce
    vmovups ymm1, [A + r10*4]  ; load eight a values without requiring 32-byte alignment
    vmulps ymm1, ymm1, [B + r10*4]  ; multiply corresponding a and b lanes
    vaddps ymm0, ymm0, ymm1  ; accumulate products separately in each lane
    add r10, 8  ; advance by eight elements, not eight bytes
    jmp .vector
.reduce:
    vextractf128 xmm1, ymm0, 1  ; copy lanes 4..7 out of the upper 128-bit half
    vaddps xmm0, xmm0, xmm1  ; combine upper/lower halves: eight partial sums become four
    vhaddps xmm0, xmm0, xmm0  ; pairwise horizontal reduction (repeat to obtain total in lane 0)
    vhaddps xmm0, xmm0, xmm0  ; pairwise horizontal reduction (repeat to obtain total in lane 0)
.tail:
    cmp r10, COUNT  ; tail bound uses original n, not the rounded vector boundary
    jae .done
    vmovss xmm1, [A + r10*4]  ; read one remaining a value
    vmulss xmm1, xmm1, [B + r10*4]  ; one scalar product for the tail
    vaddss xmm0, xmm0, xmm1  ; add that product to the scalar total in xmm0
    inc r10
    jmp .tail
.done:
    vzeroupper  ; clear upper YMM halves before returning to non-AVX C code
    ret
NOTE
