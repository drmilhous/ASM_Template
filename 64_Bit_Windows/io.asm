; io.asm for Windows x64 (nasm -f win64).
;   print_int     prints eax as a signed decimal number
;   print_hex     prints rax as 16 hex digits
;   print_nl      prints a newline
;   print_string  prints the zero-terminated string at [rax]
;   print_float   prints the double in xmm0 (printf "%f")
;   dump_registers prints all general registers (RAX..R15, RSP, RBP) in hex
;   read_int      reads one line and returns it as a signed decimal number in eax (sign-extended into rax)
;   read_float    reads one line and returns it as a double in xmm0
;   read_string   reads one line into the buffer at [rax]; rdx = buffer size in bytes (including the
;                 terminating 0). The newline is removed and the string is always zero-terminated.
;                 Returns rax = number of characters stored, or -1 at end of input (buffer = "").
;                 Characters that do not fit are thrown away, so the next read starts on a new line.
; All three read a whole line, so you can mix them freely (no leftover newline problems). Input that
; is not a number gives 0 (read_int) or 0.0 (read_float). The register that holds the result is the
; only one that changes (the flags change too); read_float keeps every general register.
; Same calling style as the Linux template: the number (or the string address) to print is in RAX
; (the double in XMM0). Every routine keeps all the general registers and xmm0 (the flags change),
; so you can call them anywhere. Each one follows the
; Microsoft x64 rules for its own call to printf: it reserves 32 bytes of shadow space and aligns
; the stack to 16 bytes itself. %llX is used for 64-bit hex because %lX is only 32 bits on Windows.
;
; (The previous io.asm here was a copy of the Linux System V one: it passed arguments in rdi/rsi
; and called "printf wrt ..plt", which does not assemble for win64.)
default rel
segment .data
printInt:     db "%d", 0
printHex:     db "%016llX", 0
printNewline: db 10, 0
printString:  db "%s", 0
printFloat:   db "%f", 0

readLineSize equ 256

dumpLine1: db "RAX: %016llX RBX: %016llX RCX: %016llX RDX: %016llX R8 : %016llX R9 : %016llX", 10, 0
dumpLine2: db "R10: %016llX R11: %016llX R12: %016llX R13: %016llX R14: %016llX R15: %016llX", 10, 0
dumpLine3: db "RSI: %016llX RDI: %016llX RSP: %016llX RBP: %016llX", 10, 0

segment .bss
readLine:     resb readLineSize   ; line buffer for read_int / read_float

extern printf
extern fgets
extern getchar
extern strlen
extern strtol
extern strtod
extern __acrt_iob_func          ; __acrt_iob_func(0) is stdin in the Universal C Runtime

segment .text
global print_int
global print_hex
global print_nl
global print_string
global print_float
global dump_registers
global read_int
global read_float
global read_string

; Save the registers printf may change and line up the stack. Uses rbp as the frame pointer.
%macro LIB_ENTER 0
        push rbp
        mov  rbp, rsp
        push rax
        push rcx
        push rdx
        push r8
        push r9
        push r10
        push r11                ; seven registers = 56 bytes below rbp
        sub  rsp, 16
        movups [rsp], xmm0      ; keep xmm0 for the caller (printf changes it)
        and  rsp, -16           ; 16-byte alignment, whatever the caller did
        sub  rsp, 32            ; shadow space
%endmacro

%macro LIB_LEAVE 0
        movups xmm0, [rbp - 72]
        lea  rsp, [rbp - 56]
        pop  r11
        pop  r10
        pop  r9
        pop  r8
        pop  rdx
        pop  rcx
        pop  rax
        pop  rbp
        ret
%endmacro

print_int:
        LIB_ENTER
        mov  edx, eax
        lea  rcx, [printInt]
        call printf
        LIB_LEAVE

print_hex:
        LIB_ENTER
        mov  rdx, rax
        lea  rcx, [printHex]
        call printf
        LIB_LEAVE

print_nl:
        LIB_ENTER
        lea  rcx, [printNewline]
        call printf
        LIB_LEAVE

print_string:
        LIB_ENTER
        mov  rdx, rax
        lea  rcx, [printString]
        call printf
        LIB_LEAVE

print_float:
        LIB_ENTER
        movq rdx, xmm0          ; a double in a variadic call travels in the xmm AND the integer register
        movapd xmm1, xmm0
        lea  rcx, [printFloat]
        call printf
        LIB_LEAVE

dump_registers:
        push rbp
        mov  rbp, rsp
        push rax                ; [rbp-8]
        push rbx                ; [rbp-16]
        push rcx                ; [rbp-24]
        push rdx                ; [rbp-32]
        push rsi                ; [rbp-40]
        push rdi                ; [rbp-48]
        push r8                 ; [rbp-56]
        push r9                 ; [rbp-64]
        push r10                ; [rbp-72]
        push r11                ; [rbp-80]
        push r12                ; [rbp-88]
        push r13                ; [rbp-96]
        push r14                ; [rbp-104]
        push r15                ; [rbp-112]
        sub  rsp, 16
        movups [rsp], xmm0
        and  rsp, -16
        sub  rsp, 64            ; 32 bytes of shadow space + room for 3 stack arguments (+ padding)

        lea  rcx, [dumpLine1]   ; RAX RBX RCX RDX R8 R9: the first three go in registers
        mov  rdx, [rbp - 8]
        mov  r8,  [rbp - 16]
        mov  r9,  [rbp - 24]
        mov  rax, [rbp - 32]    ; the rest go on the stack, above the shadow space
        mov  [rsp + 32], rax
        mov  rax, [rbp - 56]
        mov  [rsp + 40], rax
        mov  rax, [rbp - 64]
        mov  [rsp + 48], rax
        call printf

        lea  rcx, [dumpLine2]   ; R10 R11 R12 R13 R14 R15
        mov  rdx, [rbp - 72]
        mov  r8,  [rbp - 80]
        mov  r9,  [rbp - 88]
        mov  rax, [rbp - 96]
        mov  [rsp + 32], rax
        mov  rax, [rbp - 104]
        mov  [rsp + 40], rax
        mov  rax, [rbp - 112]
        mov  [rsp + 48], rax
        call printf

        lea  rcx, [dumpLine3]   ; RSI RDI RSP RBP
        mov  rdx, [rbp - 40]
        mov  r8,  [rbp - 48]
        lea  r9,  [rbp + 16]    ; rsp as it was before the call to dump_registers
        mov  rax, [rbp]         ; the caller's rbp
        mov  [rsp + 32], rax
        call printf

        movups xmm0, [rbp - 128]
        lea  rsp, [rbp - 112]
        pop  r15
        pop  r14
        pop  r13
        pop  r12
        pop  r11
        pop  r10
        pop  r9
        pop  r8
        pop  rdi
        pop  rsi
        pop  rdx
        pop  rcx
        pop  rbx
        pop  rax
        pop  rbp
        ret

read_int:
        LIB_ENTER
        lea  rcx, [readLine]
        mov  edx, readLineSize
        call read_line
        lea  rcx, [readLine]
        xor  edx, edx           ; no end pointer
        mov  r8d, 10            ; base 10
        call strtol             ; long is 32 bits on Windows
        movsxd rax, eax
        mov  [rbp - 8], rax     ; becomes the caller's rax in LIB_LEAVE
        LIB_LEAVE

read_float:
        LIB_ENTER
        lea  rcx, [readLine]
        mov  edx, readLineSize
        call read_line
        lea  rcx, [readLine]
        xor  edx, edx
        call strtod             ; result in xmm0
        movsd [rbp - 72], xmm0  ; becomes the caller's xmm0 in LIB_LEAVE
        LIB_LEAVE

read_string:
        LIB_ENTER
        mov  rcx, rax           ; buffer
        call read_line          ; rdx = size is already in place
        mov  [rbp - 8], rax
        LIB_LEAVE

; Internal: an ordinary Microsoft x64 function. rcx = buffer, rdx = size.
; Returns rax = length (newline removed) or -1 at end of input.
read_line:
        push rbx
        push rsi
        push rdi
        sub  rsp, 32            ; shadow space; 3 pushes + return address keep rsp 16-byte aligned
        mov  rbx, rcx
        mov  rsi, rdx
        xor  eax, eax
        test rsi, rsi
        jle  .done              ; no room at all: read nothing
        mov  eax, 0x7FFFFFFF
        cmp  rsi, rax
        cmova rsi, rax          ; fgets takes an int size
        xor  ecx, ecx
        call __acrt_iob_func    ; rax = stdin
        mov  r8, rax
        mov  rcx, rbx
        mov  edx, esi
        call fgets
        test rax, rax
        jz   .eof
        mov  rcx, rbx
        call strlen
        mov  rdi, rax
        test rdi, rdi
        jz   .discard           ; buffer of size 1: nothing fit
        cmp  byte [rbx + rdi - 1], 10
        jne  .discard           ; no newline: the line was longer than the buffer
        dec  rdi
        mov  byte [rbx + rdi], 0
        jmp  .strip_cr
.discard:                       ; throw away the rest of the line
        call getchar
        cmp  eax, 10
        je   .strip_cr
        cmp  eax, -1
        jne  .discard
.strip_cr:                      ; a CRLF file read in binary mode leaves a \r
        test rdi, rdi
        jz   .length
        cmp  byte [rbx + rdi - 1], 13
        jne  .length
        dec  rdi
        mov  byte [rbx + rdi], 0
.length:
        mov  rax, rdi
.done:
        add  rsp, 32
        pop  rdi
        pop  rsi
        pop  rbx
        ret
.eof:
        mov  byte [rbx], 0
        mov  rax, -1
        jmp  .done
