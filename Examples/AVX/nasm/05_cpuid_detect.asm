; Detect which SIMD level this CPU AND operating system support.
; A CPUID feature bit is not enough for AVX: the OS must also save the wider
; registers on a context switch, which XGETBV (XCR0) reports.
; Uses the ASM_Template I/O library; see platform.inc.
; Build: make 05_cpuid_detect   (Linux/macOS)   or   .\quickBuild.ps1 05_cpuid_detect   (Windows)

%include "platform.inc"
default rel
global ASM_MAIN

section .data align=64
    f_sse2   db "SSE2      : ", 0
    f_avx    db "AVX       : ", 0
    f_avx2   db "AVX2      : ", 0
    f_fma    db "FMA3      : ", 0
    f_avx512 db "AVX-512F  : ", 0
    yes      db "yes", 0
    no       db "no", 0

section .text
; r12d = bit mask results, r13d = XCR0 low word
ASM_MAIN:
    push rbp
    mov rbp, rsp
    push rbx                        ; cpuid clobbers ebx, which is callee-saved
    push r12
    push r13
    sub rsp, 8                      ; rbp + 3 pushes + 8: keeps the stack 16-byte aligned

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
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; show(r8 = label string, r9d = feature mask): prints "label yes" or "label no"
; (a private convention, not the C ABI; r12d holds the results)
show:
    push rbx                        ; also aligns the stack for the library calls
    mov ebx, r9d
    PRINT_PTR r8
    test r12d, ebx
    jz .n
    PRINT_STR yes
    jmp .nl
.n:
    PRINT_STR no
.nl:
    PRINT_NL
    pop rbx
    ret

GNU_STACK_NOTE
