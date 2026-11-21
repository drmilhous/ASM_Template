// Detect which SIMD level this CPU AND operating system support.
// A CPUID feature bit is not enough for AVX: the OS must also save the wider
// registers on a context switch, which XGETBV (XCR0) reports.
// GNU as, AT&T syntax. Uses the ASM_Template I/O library; see platform.h.
// Build: make 05_cpuid_detect    (NASM version of the same program: ../nasm/05_cpuid_detect.asm)

#include "platform.h"

    .globl ASM_MAIN

    .data
f_sse2:   .asciz "SSE2      : "
f_avx:    .asciz "AVX       : "
f_avx2:   .asciz "AVX2      : "
f_fma:    .asciz "FMA3      : "
f_avx512: .asciz "AVX-512F  : "
yes:      .asciz "yes"
no:       .asciz "no"

    .text
// r12d = bit mask results, r13d = XCR0 low word
ASM_MAIN:
    push %rbp
    mov %rsp, %rbp
    push %rbx                           // cpuid clobbers ebx, which is callee-saved
    push %r12
    push %r13
    sub $8, %rsp                        // rbp + 3 pushes + 8: keeps the stack 16-byte aligned

    xor %r12d, %r12d
    mov $1, %eax
    cpuid                               // leaf 1: ecx/edx feature flags
    bt $26, %edx                        // SSE2
    jnc .Lno_sse2
    or $1, %r12d
.Lno_sse2:
    bt $12, %ecx                        // FMA3
    jnc .Lno_fma
    or $8, %r12d
.Lno_fma:
    bt $27, %ecx                        // OSXSAVE: the OS enabled XGETBV
    jnc .Lreport
    bt $28, %ecx                        // AVX hardware bit
    jnc .Lreport
    xor %ecx, %ecx
    xgetbv                              // eax = XCR0
    mov %eax, %r13d
    and $6, %eax                        // bits 1 and 2: XMM and YMM state saved
    cmp $6, %eax
    jne .Lreport
    or $2, %r12d                        // AVX usable

    mov $7, %eax
    xor %ecx, %ecx
    cpuid                               // leaf 7: ebx has AVX2 (bit 5) and AVX-512F (bit 16)
    bt $5, %ebx
    jnc .Ltry512
    or $4, %r12d
.Ltry512:
    bt $16, %ebx
    jnc .Lreport
    mov %r13d, %eax
    and $0xE0, %eax                     // bits 5-7: opmask, ZMM_Hi256, Hi16_ZMM state saved
    cmp $0xE0, %eax
    jne .Lreport
    or $16, %r12d

.Lreport:
    lea f_sse2(%rip), %r8
    mov $1, %r9d
    call show
    lea f_avx(%rip), %r8
    mov $2, %r9d
    call show
    lea f_avx2(%rip), %r8
    mov $4, %r9d
    call show
    lea f_fma(%rip), %r8
    mov $8, %r9d
    call show
    lea f_avx512(%rip), %r8
    mov $16, %r9d
    call show

    xor %eax, %eax
    add $8, %rsp
    pop %r13
    pop %r12
    pop %rbx
    pop %rbp
    ret

// show(r8 = label string, r9d = feature mask): prints "label yes" or "label no"
// (a private convention, not the C ABI; r12d holds the results)
show:
    push %rbx                           // also aligns the stack for the library calls
    mov %r9d, %ebx
    PRINT_PTR %r8
    test %ebx, %r12d
    jz .Ln
    PRINT_STR yes
    jmp .Lnl
.Ln:
    PRINT_STR no
.Lnl:
    PRINT_NL
    pop %rbx
    ret

GNU_STACK_NOTE
