; Windows ARM64 (armasm64): looking at the REAL system call.
;
; !! On Windows ARM64 the system call number is the immediate of the SVC instruction
; !! itself:  "svc #N".  It cannot be put in a register, so unlike x64 you cannot
; !! write one generic "do_syscall" helper; every call needs its own svc.  N changes
; !! between Windows versions and builds and is undocumented, so never hard-code it.
; !! The reliable way to make a raw call is the tiny stub ntdll.dll exports for each
; !! call.  Each stub is just:
; !!       svc  #N
; !!       ret
;
; This program (1) finds NtWriteFile in ntdll, (2) decodes the SVC instruction to show
; N on THIS machine, (3) calls the stub to write a message (that call IS the syscall),
; (4) ends the process with NtTerminateProcess, again via its stub.
; Other calls (NtOpenFile, NtReadFile, NtAllocateVirtualMemory, NtClose ...) work the same.
; Build + run: .\quickBuild.ps1
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  start
    IMPORT  GetModuleHandleA
    IMPORT  GetProcAddress
    IMPORT  GetStdHandle
    IMPORT  WriteFile
    IMPORT  ExitProcess

write_buf PROC                          ; x1 = buffer, x2 = length (via kernel32 WriteFile)
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    adrp    x0, hOut
    add     x0, x0, hOut
    ldr     x0, [x0]
    adrp    x3, count
    add     x3, x3, count
    mov     x4, #0
    bl      WriteFile
    ldp     fp, lr, [sp], #16
    ret
    ENDP

write_z PROC                            ; x0 = zero-terminated string
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    mov     x1, x0
    mov     x2, #0
wz_len
    ldrb    w3, [x1, x2]
    cbz     w3, wz_go
    add     x2, x2, #1
    b       wz_len
wz_go
    bl      write_buf
    ldp     fp, lr, [sp], #16
    ret
    ENDP

print_dec PROC                          ; x0 = value; prints decimal + CR LF
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    adrp    x1, numbuf
    add     x1, x1, numbuf
    mov     w3, #0
    strb    w3, [x1, #22]
    mov     w3, #13
    strb    w3, [x1, #20]
    mov     w3, #10
    strb    w3, [x1, #21]
    add     x1, x1, #20
    mov     x5, #10
pd_loop
    udiv    x6, x0, x5
    msub    x7, x6, x5, x0
    add     w7, w7, #48
    sub     x1, x1, #1
    strb    w7, [x1]
    mov     x0, x6
    cbnz    x0, pd_loop
    mov     x0, x1
    bl      write_z
    ldp     fp, lr, [sp], #16
    ret
    ENDP

; get_stub: x0 = module handle, x1 = function name.  Returns x0 = address of the stub.
get_stub PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    bl      GetProcAddress
    ldp     fp, lr, [sp], #16
    ret
    ENDP

start PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp

    movn    w0, #10                     ; STD_OUTPUT_HANDLE (-11)
    bl      GetStdHandle
    adrp    x1, hOut
    add     x1, x1, hOut
    str     x0, [x1]

    adrp    x0, ntdll
    add     x0, x0, ntdll
    bl      GetModuleHandleA
    mov     x19, x0                     ; ntdll base

    mov     x0, x19
    adrp    x1, n_write
    add     x1, x1, n_write
    bl      get_stub
    mov     x20, x0                     ; NtWriteFile stub
    cbz     x20, nostub

    ; Decode "svc #N":  encoding is 0xD4000001 | (N << 5)
    ldr     w21, [x20]
    movz    w22, #0xFFE0, lsl #16
    movk    w22, #0x001F                ; mask 0xFFE0001F
    and     w23, w21, w22
    movz    w24, #0xD400, lsl #16
    movk    w24, #0x0001                ; 0xD4000001
    cmp     w23, w24
    bne     nostub
    ubfx    w21, w21, #5, #16           ; N
    adrp    x0, ssnmsg
    add     x0, x0, ssnmsg
    bl      write_z
    mov     x0, x21
    bl      print_dec

    mov     x0, x19
    adrp    x1, n_term
    add     x1, x1, n_term
    bl      get_stub
    mov     x22, x0                     ; NtTerminateProcess stub
    cbz     x22, nostub

    ; NtWriteFile(FileHandle, Event, ApcRoutine, ApcContext, IoStatusBlock,
    ;             Buffer, Length, ByteOffset, Key)  - 9 args: x0..x7, 9th on the stack
    sub     sp, sp, #16
    str     xzr, [sp]                   ; 9th: Key = NULL
    adrp    x0, hOut
    add     x0, x0, hOut
    ldr     x0, [x0]                    ; FileHandle
    mov     x1, #0                      ; Event
    mov     x2, #0                      ; ApcRoutine
    mov     x3, #0                      ; ApcContext
    adrp    x4, iosb
    add     x4, x4, iosb                ; IoStatusBlock
    adrp    x5, msg
    add     x5, x5, msg                 ; Buffer
    mov     x6, #54                     ; Length of msg below (incl. CR LF)
    mov     x7, #0                      ; ByteOffset = NULL
    blr     x20                         ; the stub runs "svc #N" for us
    add     sp, sp, #16

    ; NtTerminateProcess(NtCurrentProcess() = -1, status 0)
    mov     x0, #-1
    mov     x1, #0
    blr     x22
    ; not reached
nostub
    adrp    x0, hookmsg
    add     x0, x0, hookmsg
    bl      write_z
    mov     w0, #1
    bl      ExitProcess
    ENDP

    AREA    |.rdata|, DATA, READONLY
ntdll   DCB     "ntdll.dll", 0
n_write DCB     "NtWriteFile", 0
n_term  DCB     "NtTerminateProcess", 0
ssnmsg  DCB     "NtWriteFile is system call number (the immediate of its svc): ", 0
msg     DCB     "Hello from a raw Windows ARM64 syscall (NtWriteFile)", 13, 10
hookmsg DCB     "ntdll stub does not start with svc (hooked or changed layout?)", 13, 10, 0

    AREA    |.data|, DATA, READWRITE, ALIGN=3
hOut    DCQ     0
iosb    SPACE   16
count   DCD     0
numbuf  SPACE   24

    END
