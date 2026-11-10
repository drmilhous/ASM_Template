; Windows ARM64 (armasm64): the SUPPORTED route - Win32 API calls into kernel32.dll
; (which call ntdll.dll, which finally executes the real "svc" instruction).
; Same five steps as the Linux/macOS examples.  Build + run: .\quickBuild.ps1
; Convention (ARM64 Windows): args X0..X7, then the stack; result in X0;
;   X19-X28 are preserved across calls; X18 is reserved by Windows (never touch it).
; Strings are zero-terminated and printed with write_z (it finds the length itself).
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  start
    IMPORT  GetStdHandle
    IMPORT  WriteFile
    IMPORT  GetCurrentProcessId
    IMPORT  CreateFileA
    IMPORT  ReadFile
    IMPORT  CloseHandle
    IMPORT  VirtualAlloc
    IMPORT  VirtualFree
    IMPORT  ExitProcess

; write_buf: x1 = buffer, x2 = length.   WriteFile(hOut, buf, len, &count, NULL)
write_buf PROC
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

; write_z: x0 = address of a zero-terminated string
write_z PROC
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

; print_dec: x0 = value; prints it in decimal followed by CR LF
print_dec PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    adrp    x1, numbuf
    add     x1, x1, numbuf
    mov     w3, #0
    strb    w3, [x1, #22]               ; terminator
    mov     w3, #13
    strb    w3, [x1, #20]               ; CR
    mov     w3, #10
    strb    w3, [x1, #21]               ; LF
    add     x1, x1, #20
    mov     x5, #10
pd_loop
    udiv    x6, x0, x5
    msub    x7, x6, x5, x0              ; remainder
    add     w7, w7, #48                 ; '0'
    sub     x1, x1, #1
    strb    w7, [x1]
    mov     x0, x6
    cbnz    x0, pd_loop
    mov     x0, x1
    bl      write_z
    ldp     fp, lr, [sp], #16
    ret
    ENDP

start PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp

    ; 1. GetStdHandle(STD_OUTPUT_HANDLE = -11) + WriteFile
    movn    w0, #10                     ; w0 = -11
    bl      GetStdHandle
    adrp    x1, hOut
    add     x1, x1, hOut
    str     x0, [x1]
    adrp    x0, msg
    add     x0, x0, msg
    bl      write_z

    ; 2. GetCurrentProcessId
    adrp    x0, pidmsg
    add     x0, x0, pidmsg
    bl      write_z
    bl      GetCurrentProcessId
    bl      print_dec

    ; 3. CreateFileA / ReadFile / CloseHandle
    adrp    x0, filemsg
    add     x0, x0, filemsg
    bl      write_z
    adrp    x0, path
    add     x0, x0, path
    movz    w1, #0x8000, lsl #16        ; GENERIC_READ
    mov     w2, #1                      ; FILE_SHARE_READ
    mov     x3, #0                      ; no security attributes
    mov     w4, #3                      ; OPEN_EXISTING
    mov     w5, #0                      ; flags and attributes
    mov     x6, #0                      ; no template file
    bl      CreateFileA
    cmn     x0, #1                      ; INVALID_HANDLE_VALUE (-1)?
    beq     fail
    mov     x19, x0                     ; file handle (X19 survives calls)
    adrp    x1, rdbuf
    add     x1, x1, rdbuf
    mov     w2, #40
    adrp    x3, count
    add     x3, x3, count
    mov     x4, #0
    bl      ReadFile
    cbz     w0, fail
    adrp    x2, count
    add     x2, x2, count
    ldr     w2, [x2]                    ; bytes actually read
    adrp    x1, rdbuf
    add     x1, x1, rdbuf
    bl      write_buf
    adrp    x0, crlf
    add     x0, x0, crlf
    bl      write_z
    mov     x0, x19
    bl      CloseHandle

    ; 4. VirtualAlloc / VirtualFree
    mov     x0, #0
    mov     w1, #4096
    mov     w2, #0x3000                 ; MEM_COMMIT | MEM_RESERVE
    mov     w3, #4                      ; PAGE_READWRITE
    bl      VirtualAlloc
    cbz     x0, fail
    mov     x20, x0                     ; page address
    adrp    x1, mapmsg
    add     x1, x1, mapmsg
    mov     x3, x20
cp_loop
    ldrb    w4, [x1], #1                ; copy the text (and its zero) into the page
    strb    w4, [x3], #1
    cbnz    w4, cp_loop
    mov     x0, x20
    bl      write_z
    mov     x0, x20
    mov     x1, #0                      ; size must be 0 with MEM_RELEASE
    movz    w2, #0x8000                 ; MEM_RELEASE
    bl      VirtualFree

    ; 5. ExitProcess(0)
    mov     w0, #0
    bl      ExitProcess
fail
    mov     w0, #1
    bl      ExitProcess
    ENDP

    AREA    |.rdata|, DATA, READONLY
msg     DCB     "1. WriteFile: Hello from the Win32 API on ARM64", 13, 10, 0
pidmsg  DCB     "2. GetCurrentProcessId: ", 0
filemsg DCB     "3. CreateFileA/ReadFile/CloseHandle hosts file (first 40 bytes):", 13, 10, 0
mapmsg  DCB     "4. VirtualAlloc: wrote this text into a fresh page", 13, 10, 0
path    DCB     "C:\\Windows\\System32\\drivers\\etc\\hosts", 0
crlf    DCB     13, 10, 0

    AREA    |.data|, DATA, READWRITE, ALIGN=3
hOut    DCQ     0
count   DCD     0
numbuf  SPACE   24
rdbuf   SPACE   41

    END
