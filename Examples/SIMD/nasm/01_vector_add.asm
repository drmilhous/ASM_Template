; void simd_operation(const float *a, const float *b, float *out, size_t n)
; AVX: eight float lanes per iteration; unaligned loads and a scalar tail.
%include "platform.inc"
global ASM_MAIN, OP
section .data align=32
global DATA_A, DATA_N
DATA_N: dq 9                    ; nine elements include a scalar tail
DATA_A: dd -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5
global DATA_B
DATA_B: dd -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, -1.5, -1.0
global DATA_OUT
DATA_OUT: times 9 dd 0           ; writable output array in .data

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
    lea OUT, [rel DATA_OUT]
    mov COUNT, [rel DATA_N]
    call OP                     ; operation reads the arrays from memory
%ifidn __OUTPUT_FORMAT__, win64
    add rsp, 40
%else
    add rsp, 8
%endif
    ret                         ; scalar result remains in xmm0 or eax

; The driver also calls this function directly for independent test inputs.
OP:
    xor r10d, r10d  ; element index i = 0; writing r10d also clears the upper 32 bits
    mov r11, COUNT  ; retain n in COUNT; r11 will be the full-vector boundary
    and r11, -8  ; round n down to a multiple of 8; never read a partial vector
.vector:
    cmp r10, r11  ; is there a complete group of eight elements left?
    jae .tail
    vmovups ymm0, [A + r10*4]  ; load a[i..i+7]; scale 4 converts an element index to bytes
    vaddps ymm1, ymm0, [B + r10*4]  ; eight lane-wise additions; ymm0 remains unchanged
    vmovups [OUT + r10*4], ymm1  ; write exactly eight results to out[i..i+7]
    add r10, 8  ; advance by eight elements, not eight bytes
    jmp .vector
.tail:
    cmp r10, COUNT  ; tail bound uses original n, not the rounded vector boundary
    jae .done
    vmovss xmm0, [A + r10*4]  ; read one remaining float; do not load past the end
    vaddss xmm0, xmm0, [B + r10*4]  ; scalar addition affects only the low float lane
    vmovss [OUT + r10*4], xmm0  ; write only one float, leaving the rest of memory alone
    inc r10
    jmp .tail
.done:
    vzeroupper  ; clear upper YMM halves before returning to non-AVX C code
    ret
NOTE
