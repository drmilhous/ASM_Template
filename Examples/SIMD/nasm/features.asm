; Return bit 0 = usable AVX, bit 1 = usable AVX2. No vector instructions.
; XGETBV is executed only after checking XSAVE, OSXSAVE, and AVX.
%include "platform.inc"
global FEATURES
section .text
FEATURES:
    push rbx                       ; CPUID clobbers this nonvolatile register
    xor r10d, r10d
    xor eax, eax
    cpuid
    mov r11d, eax                   ; maximum basic CPUID leaf
    cmp eax, 1
    jb .done
    mov eax, 1
    cpuid
    and ecx, 0x1c000000             ; XSAVE + OSXSAVE + AVX
    cmp ecx, 0x1c000000
    jne .done
    xor ecx, ecx
    xgetbv
    and eax, 6                     ; OS enables both XMM and YMM state
    cmp eax, 6
    jne .done
    mov r10d, 1
    cmp r11d, 7
    jb .done
    mov eax, 7
    xor ecx, ecx
    cpuid
    test ebx, 1 << 5                ; AVX2
    jz .done
    or r10d, 2
.done:
    mov eax, r10d
    pop rbx
    ret
NOTE
