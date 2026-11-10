; macOS x86-64 (Intel, or Apple silicon under Rosetta) raw BSD system calls.
; Build: make   Run: ./syscalls
; Convention: syscall number in RAX = 0x2000000 + BSD number (class 2 = BSD),
;             args in RDI, RSI, RDX, R10, R8, R9.  Execute "syscall".
;             On error the CARRY flag is set and RAX holds the (positive) errno.
;             RCX, R11 (and RDX on some calls) are destroyed.
; Numbers: exit=1 read=3 write=4 open=5 close=6 getpid=20 munmap=73 mmap=197
; Apple does not promise raw syscalls stay stable; libSystem is the supported API.
default rel

BSD         equ 0x2000000
SYS_exit    equ BSD + 1
SYS_read    equ BSD + 3
SYS_write   equ BSD + 4
SYS_open    equ BSD + 5
SYS_close   equ BSD + 6
SYS_getpid  equ BSD + 20
SYS_munmap  equ BSD + 73
SYS_mmap    equ BSD + 197

section .data
msg:     db "1. write: Hello from a raw macOS x64 syscall", 10
msg_len  equ $ - msg
pidmsg:  db "2. getpid: "
pidmsg_len equ $ - pidmsg
filemsg: db "3. open/read/close /etc/hosts (first 40 bytes):", 10
filemsg_len equ $ - filemsg
mapmsg:  db "4. mmap: wrote this text into an anonymous page", 10
mapmsg_len equ $ - mapmsg
path:    db "/etc/hosts", 0
nl:      db 10

section .bss
numbuf:  resb 24
rdbuf:   resb 40

section .text
global _start

; write(1, rsi, rdx)
do_write:
        mov     edi, 1
        mov     eax, SYS_write
        syscall
        ret

; print RDI as decimal + newline
print_dec:
        lea     rsi, [numbuf + 20]
        mov     byte [rsi], 10
        mov     rax, rdi
        mov     ecx, 10
.next:  xor     edx, edx
        div     rcx
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        test    rax, rax
        jnz     .next
        lea     rdx, [numbuf + 21]
        sub     rdx, rsi
        jmp     do_write

_start:
        ; 1. write
        lea     rsi, [msg]
        mov     edx, msg_len
        call    do_write

        ; 2. getpid
        lea     rsi, [pidmsg]
        mov     edx, pidmsg_len
        call    do_write
        mov     eax, SYS_getpid
        syscall
        mov     rdi, rax
        call    print_dec

        ; 3. open / read / write / close
        lea     rsi, [filemsg]
        mov     edx, filemsg_len
        call    do_write
        mov     eax, SYS_open
        lea     rdi, [path]
        xor     esi, esi                ; O_RDONLY
        xor     edx, edx
        syscall
        jc      .fail                   ; carry = error
        mov     r12, rax                ; fd
        mov     eax, SYS_read
        mov     rdi, r12
        lea     rsi, [rdbuf]
        mov     edx, 40
        syscall
        jc      .fail
        mov     rdx, rax
        lea     rsi, [rdbuf]
        call    do_write
        lea     rsi, [nl]
        mov     edx, 1
        call    do_write
        mov     eax, SYS_close
        mov     rdi, r12
        syscall

        ; 4. mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0)
        ;    macOS: MAP_PRIVATE = 0x2, MAP_ANON = 0x1000 (differs from Linux!)
        mov     eax, SYS_mmap
        xor     edi, edi
        mov     esi, 4096
        mov     edx, 3
        mov     r10d, 0x1002
        mov     r8, -1
        xor     r9d, r9d
        syscall
        jc      .fail
        mov     r13, rax
        lea     rsi, [mapmsg]
        mov     rdi, r13
        mov     ecx, mapmsg_len
        cld
        rep movsb
        mov     rsi, r13
        mov     edx, mapmsg_len
        call    do_write
        mov     eax, SYS_munmap
        mov     rdi, r13
        mov     esi, 4096
        syscall

        ; 5. exit(0)
        xor     edi, edi
        mov     eax, SYS_exit
        syscall
.fail:
        mov     edi, 1
        mov     eax, SYS_exit
        syscall
