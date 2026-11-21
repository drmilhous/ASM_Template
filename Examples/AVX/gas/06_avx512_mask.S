// AVX-512: 16 floats per zmm register, and opmask registers (k1..k7).
// A mask lets one vector instruction handle the "tail" of a loop, so no scalar clean-up loop is needed.
// Here: add arrays of 21 floats = one full vector of 16 + a masked vector of 5.
// GNU as, AT&T syntax: the mask goes on the DESTINATION, e.g. %zmm0{%k1}{z}.
// Needs an AVX-512F CPU. Build: make 06_avx512_mask
// NASM version of the same program: ../nasm/06_avx512_mask.asm

    #include "platform.h"

    .globl MAIN
    .set COUNT, 21

    .data
    .balign 64
a:  .rept 32
    .float 1.5 // padding beyond COUNT is never read thanks to the mask
    .endr
b:  .rept 32
    .float 2.5
    .endr
fmt: .asciz "sum of c[0..20] = %.1f (expected 84.0)\n"

    .bss
    .balign 64
c:  .skip 128

    .text
MAIN:
    push %rbx

    lea a(%rip), %r9
    lea b(%rip), %r10
    lea c(%rip), %r8
    xor %ecx, %ecx // element index
.Lloop:
    mov $COUNT, %edx
    sub %ecx, %edx // elements left
    jle .Ldone
    cmp $16, %edx
    jb .Lmasked
    vmovups (%r9,%rcx,4), %zmm0
    vaddps  (%r10,%rcx,4), %zmm0, %zmm0
    vmovups %zmm0, (%r8,%rcx,4)
    add $16, %ecx
    jmp .Lloop

.Lmasked:
    mov $1, %eax
    shlx %edx, %eax, %eax // 1 << left (AT&T: count, source, destination)
    dec %eax // low "left" bits set
    kmovw %eax, %k1
    vmovups (%r9,%rcx,4), %zmm0{%k1}{z} // masked-off lanes are zeroed and not read (no fault)
    vaddps  (%r10,%rcx,4), %zmm0, %zmm0{%k1}{z}
    vmovups %zmm0, (%r8,%rcx,4){%k1} // masked store writes only the selected lanes
.Ldone:
    // sum c[0..20] with scalar code to show the result
    vzeroupper
    xorps %xmm0, %xmm0
    xor %ecx, %ecx
.Lsum:
    addss (%r8,%rcx,4), %xmm0
    inc %ecx
    cmp $COUNT, %ecx
    jb .Lsum
    cvtss2sd %xmm0, %xmm0
    lea fmt(%rip), ARG1
    DOUBLE_ARG2
    mov $1, %eax
    CCALL PRINTF

    xor %eax, %eax
    pop %rbx
    ret

GNU_STACK_NOTE
