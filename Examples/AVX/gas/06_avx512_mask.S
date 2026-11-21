// AVX-512: 16 floats per zmm register, and opmask registers (k1..k7).
// A mask lets one vector instruction handle the "tail" of a loop, so no scalar clean-up loop is needed.
// Here: add arrays of 21 floats = one full vector of 16 + a masked vector of 5.
// GNU as, AT&T syntax: the mask goes on the DESTINATION, e.g. %zmm0{%k1}{z}.
// Needs an AVX-512F CPU. Uses the ASM_Template I/O library; see platform.h.
// Build: make 06_avx512_mask    (NASM version of the same program: ../nasm/06_avx512_mask.asm)

#include "platform.h"

    .globl ASM_MAIN
    .set COUNT, 21

    .data
    .balign 64
a:  .rept 32
    .float 1.5                          // padding beyond COUNT is never read thanks to the mask
    .endr
b:  .rept 32
    .float 2.5
    .endr
s_sum: .asciz "sum of c[0..20] = "
s_exp: .asciz " (expected 84)"

    .bss
    .balign 64
c:  .skip 128

    .text
ASM_MAIN:
    push %rbp
    mov %rsp, %rbp
    push %rbx                           // callee-saved: survives the library calls
    sub $8, %rsp                        // keeps the stack 16-byte aligned

    lea a(%rip), %r8
    lea b(%rip), %r9
    lea c(%rip), %r10
    xor %ecx, %ecx                      // element index
.Lloop:
    mov $COUNT, %edx
    sub %ecx, %edx                      // elements left
    jle .Ldone
    cmp $16, %edx
    jb .Lmasked
    vmovups (%r8,%rcx,4), %zmm0
    vaddps  (%r9,%rcx,4), %zmm0, %zmm0
    vmovups %zmm0, (%r10,%rcx,4)
    add $16, %ecx
    jmp .Lloop

.Lmasked:
    mov $1, %eax
    shlx %edx, %eax, %eax               // 1 << left (AT&T: count, source, destination)
    dec %eax                            // low "left" bits set
    kmovw %eax, %k1
    vmovups (%r8,%rcx,4), %zmm0{%k1}{z}         // masked-off lanes are zeroed and not read (no fault)
    vaddps  (%r9,%rcx,4), %zmm0, %zmm0{%k1}{z}
    vmovups %zmm0, (%r10,%rcx,4){%k1}           // masked store writes only the selected lanes
.Ldone:
    // sum c[0..20] with scalar code to show the result
    vzeroupper
    xorps %xmm0, %xmm0
    xor %ecx, %ecx
.Lsum:
    addss (%r10,%rcx,4), %xmm0
    inc %ecx
    cmp $COUNT, %ecx
    jb .Lsum
    cvttss2si %xmm0, %ebx

    PRINT_STR s_sum
    PRINT_INT %ebx
    PRINT_STR s_exp
    PRINT_NL

    xor %eax, %eax
    add $8, %rsp
    pop %rbx
    pop %rbp
    ret

GNU_STACK_NOTE
