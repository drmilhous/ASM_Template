; Windows x64: the SUPPORTED route - Win32 API calls into kernel32.dll (which in
; turn call ntdll.dll, which finally executes the real "syscall" instruction).
; Same five steps as the Linux/macOS examples.  Build + run: .\quickBuild.ps1
; Convention (Microsoft x64): args RCX, RDX, R8, R9, then the stack; the caller
; always reserves 32 bytes of "shadow space"; RSP must be 16-byte aligned at a call.
default rel
extern GetStdHandle
extern WriteFile
extern GetCurrentProcessId
extern CreateFileA
extern ReadFile
extern CloseHandle
extern VirtualAlloc
extern VirtualFree
extern ExitProcess

STD_OUTPUT_HANDLE equ -11
GENERIC_READ      equ 0x80000000
FILE_SHARE_READ   equ 1
OPEN_EXISTING     equ 3
MEM_COMMIT_RESERVE equ 0x3000
MEM_RELEASE       equ 0x8000
PAGE_READWRITE    equ 4

section .data
msg:     db "1. WriteFile: Hello from the Win32 API on x64", 13, 10
msg_len  equ $ - msg
pidmsg:  db "2. GetCurrentProcessId: "
pidmsg_len equ $ - pidmsg
filemsg: db "3. CreateFileA/ReadFile/CloseHandle hosts file (first 40 bytes):", 13, 10
filemsg_len equ $ - filemsg
mapmsg:  db "4. VirtualAlloc: wrote this text into a fresh page", 13, 10
mapmsg_len equ $ - mapmsg
path:    db "C:\Windows\System32\drivers\etc\hosts", 0
crlf:    db 13, 10

section .bss
hOut:    resq 1
hFile:   resq 1
page:    resq 1
count:   resd 1
numbuf:  resb 24
rdbuf:   resb 40

section .text
global start

; write_buf: RSI = buffer, EDX = length.  WriteFile(hOut, buf, len, &count, NULL)
; (RSI is only borrowed here; fine because nothing else in this program needs it.)
write_buf:
        sub     rsp, 0x28               ; shadow space + 5th arg slot, keeps alignment
        mov     rcx, [hOut]
        mov     r8d, edx
        mov     rdx, rsi
        lea     r9, [count]
        mov     qword [rsp + 0x20], 0   ; lpOverlapped = NULL
        call    WriteFile
        add     rsp, 0x28
        ret

; print_dec: EAX = value, prints decimal + CRLF
print_dec:
        lea     rsi, [numbuf + 20]
        mov     word [rsi], 0x0A0D      ; CR LF
        mov     ecx, 10
.next:  xor     edx, edx
        div     ecx
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        test    eax, eax
        jnz     .next
        lea     rdx, [numbuf + 22]
        sub     rdx, rsi
        jmp     write_buf

start:
        sub     rsp, 0x58               ; 0x20 shadow + 0x20 stack args + alignment

        ; 1. GetStdHandle + WriteFile
        mov     ecx, STD_OUTPUT_HANDLE
        call    GetStdHandle
        mov     [hOut], rax
        lea     rsi, [msg]
        mov     edx, msg_len
        call    write_buf

        ; 2. GetCurrentProcessId
        lea     rsi, [pidmsg]
        mov     edx, pidmsg_len
        call    write_buf
        call    GetCurrentProcessId
        call    print_dec

        ; 3. CreateFileA / ReadFile / CloseHandle
        lea     rsi, [filemsg]
        mov     edx, filemsg_len
        call    write_buf
        lea     rcx, [path]
        mov     edx, GENERIC_READ
        mov     r8d, FILE_SHARE_READ
        xor     r9d, r9d                            ; no security attributes
        mov     qword [rsp + 0x20], OPEN_EXISTING   ; dwCreationDisposition
        mov     qword [rsp + 0x28], 0               ; dwFlagsAndAttributes
        mov     qword [rsp + 0x30], 0               ; hTemplateFile
        call    CreateFileA
        cmp     rax, -1                             ; INVALID_HANDLE_VALUE
        je      .fail
        mov     [hFile], rax
        mov     rcx, rax
        lea     rdx, [rdbuf]
        mov     r8d, 40
        lea     r9, [count]
        mov     qword [rsp + 0x20], 0
        call    ReadFile
        test    eax, eax
        jz      .fail
        lea     rsi, [rdbuf]
        mov     edx, [count]
        call    write_buf
        lea     rsi, [crlf]
        mov     edx, 2
        call    write_buf
        mov     rcx, [hFile]
        call    CloseHandle

        ; 4. VirtualAlloc / VirtualFree
        xor     ecx, ecx
        mov     edx, 4096
        mov     r8d, MEM_COMMIT_RESERVE
        mov     r9d, PAGE_READWRITE
        call    VirtualAlloc
        test    rax, rax
        jz      .fail
        mov     [page], rax
        mov     rdi, rax
        lea     rsi, [mapmsg]
        mov     ecx, mapmsg_len
        cld
        rep movsb
        mov     rsi, [page]
        mov     edx, mapmsg_len
        call    write_buf
        mov     rcx, [page]
        xor     edx, edx                ; size must be 0 with MEM_RELEASE
        mov     r8d, MEM_RELEASE
        call    VirtualFree

        ; 5. ExitProcess(0)
        xor     ecx, ecx
        call    ExitProcess
.fail:
        mov     ecx, 1
        call    ExitProcess
