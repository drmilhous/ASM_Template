// Detect which SIMD level this CPU AND operating system support.
// A CPUID feature bit is not enough for AVX: the OS must also save the wider
// registers on a context switch, which XGETBV (XCR0) reports.
// GNU as, AT&T syntax. Build: make 05_cpuid_detect
// NASM version of the same program: ../nasm/05_cpuid_detect.asm

    #include "platform.h"

    .globl MAIN

    .data
f_sse2:   .asciz "SSE2      : %s\n"
f_avx:    .asciz "AVX       : %s\n"
f_avx2:   .asciz "AVX2      : %s\n"
f_fma:    .asciz "FMA3      : %s\n"
f_avx512: .asciz "AVX-512F  : %s\n"
yes:      .asciz "yes"
no:       .asciz "no"

    .text
// r12d = bit mask results, r13d = XCR0 low word
MAIN:
    push %rbx // cpuid clobbers ebx, which is callee-saved
    push %r12
    push %r13

    xor %r12d, %r12d
    mov $1, %eax
    cpuid // leaf 1: ecx/edx feature flags
    bt $26, %edx // SSE2
    jnc .Lno_sse2
    or $1, %r12d
.Lno_sse2:
    bt $12, %ecx // FMA3
    jnc .Lno_fma
    or $8, %r12d
.Lno_fma:
    bt $27, %ecx // OSXSAVE: the OS enabled XGETBV
    jnc .Lreport
    bt $28, %ecx // AVX hardware bit
    jnc .Lreport
    xor %ecx, %ecx
    xgetbv // eax = XCR0
    mov %eax, %r13d
    and $6, %eax // bits 1 and 2: XMM and YMM state saved
    cmp $6, %eax
    jne .Lreport
    or $2, %r12d // AVX usable

    mov $7, %eax
    xor %ecx, %ecx
    cpuid // leaf 7: ebx has AVX2 (bit 5) and AVX-512F (bit 16)
    bt $5, %ebx
    jnc .Ltry512
    or $4, %r12d
.Ltry512:
    bt $16, %ebx
    jnc .Lreport
    mov %r13d, %eax
    and $0xE0, %eax // bits 5-7: opmask, ZMM_Hi256, Hi16_ZMM state saved
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
    pop %r13
    pop %r12
    pop %rbx
    ret

// show(r8 = format, r9d = feature mask): prints yes/no (private convention, not the C ABI)
show:
    push %rbx                           // also aligns the stack for the call
    lea no(%rip), ARG2
    test %r9d, %r12d
    jz .Lp
    lea yes(%rip), ARG2
.Lp:
    mov %r8, ARG1
    xor %eax, %eax
    CCALL PRINTF
    pop %rbx
    ret

GNU_STACK_NOTE
