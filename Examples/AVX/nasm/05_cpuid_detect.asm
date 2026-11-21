; Detect which SIMD level this CPU AND operating system support.
; A CPUID feature bit is not enough for AVX: the OS must also save the wider
; registers on a context switch, which XGETBV (XCR0) reports.
; Portable: Linux, macOS (Intel) and Windows x64 (see platform.inc).
; Build: make 05_cpuid_detect   (Linux/macOS)   or   .\quickBuild.ps1 05_cpuid_detect   (Windows)

%include "platform.inc"
default rel
global MAIN

section .data align=64
    f_sse2   db "SSE2      : %s", 10, 0
    f_avx    db "AVX       : %s", 10, 0
    f_avx2   db "AVX2      : %s", 10, 0
    f_fma    db "FMA3      : %s", 10, 0
    f_avx512 db "AVX-512F  : %s", 10, 0
    yes      db "yes", 0
    no       db "no", 0

section .text
; r12d = bit mask results, r13d = XCR0 low word
MAIN:
    push rbx                        ; cpuid clobbers ebx, which is callee-saved
    push r12
    push r13

    xor r12d, r12d
    mov eax, 1
    cpuid                           ; leaf 1: ecx/edx feature flags
    bt edx, 26                      ; SSE2
    jnc .no_sse2
    or r12d, 1
.no_sse2:
    bt ecx, 12                      ; FMA3
    jnc .no_fma
    or r12d, 8
.no_fma:
    bt ecx, 27                      ; OSXSAVE: the OS enabled XGETBV
    jnc .report
    bt ecx, 28                      ; AVX hardware bit
    jnc .report
    xor ecx, ecx
    xgetbv                          ; eax = XCR0
    mov r13d, eax
    and eax, 6                      ; bits 1 and 2: XMM and YMM state saved
    cmp eax, 6
    jne .report
    or r12d, 2                      ; AVX usable

    mov eax, 7
    xor ecx, ecx
    cpuid                           ; leaf 7: ebx has AVX2 (bit 5) and AVX-512F (bit 16)
    bt ebx, 5
    jnc .try512
    or r12d, 4
.try512:
    bt ebx, 16
    jnc .report
    mov eax, r13d
    and eax, 0xE0                   ; bits 5-7: opmask, ZMM_Hi256, Hi16_ZMM state saved
    cmp eax, 0xE0
    jne .report
    or r12d, 16

.report:
    lea r8, [f_sse2]
    mov r9d, 1
    call show
    lea r8, [f_avx]
    mov r9d, 2
    call show
    lea r8, [f_avx2]
    mov r9d, 4
    call show
    lea r8, [f_fma]
    mov r9d, 8
    call show
    lea r8, [f_avx512]
    mov r9d, 16
    call show

    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; show(r8 = format, r9d = feature mask): prints yes/no (private convention, not the C ABI)
show:
    push rbx                        ; also aligns the stack for the call
    lea ARG2, [no]
    test r12d, r9d
    jz .p
    lea ARG2, [yes]
.p:
    mov ARG1, r8
    xor eax, eax
    CCALL PRINTF
    pop rbx
    ret

GNU_STACK_NOTE
