; Linux x86-64 raw system calls (no libc).  Build: make   Run: ./syscalls
; Convention: syscall number in RAX, args in RDI, RSI, RDX, R10, R8, R9.
;             Execute "syscall". Result in RAX (-4095..-1 means -errno).
;             RCX and R11 are destroyed by the instruction.
; Numbers: read=0 write=1 open=2 close=3 mmap=9 munmap=11 getpid=39 exit=60
default rel

SYS_read   equ 0
SYS_write  equ 1
SYS_open   equ 2
SYS_close  equ 3
SYS_mmap   equ 9
SYS_munmap equ 11
SYS_getpid equ 39
SYS_exit   equ 60

segment .data
msg:     db "1. write: Hello from a raw Linux x64 syscall", 10
msg_len  equ $ - msg
pidmsg:  db "2. getpid: "
pidmsg_len equ $ - pidmsg
filemsg: db "3. open/read/close /etc/hosts (first 40 bytes):", 10
filemsg_len equ $ - filemsg
mapmsg:  db "4. mmap: wrote this text into an anonymous page", 10
mapmsg_len equ $ - mapmsg
path:    db "/etc/hosts", 0
nl:      db 10

segment .bss
numbuf:  resb 24
rdbuf:   resb 40

segment .text
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
        ; 1. write(1, msg, len)
        lea     rsi, [msg]
        mov     edx, msg_len
        call    do_write

        ; 2. getpid()
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
        test    rax, rax
        js      .fail
        mov     r12, rax                ; fd
        mov     eax, SYS_read
        mov     rdi, r12
        lea     rsi, [rdbuf]
        mov     edx, 40
        syscall
        test    rax, rax
        js      .fail
        mov     rdx, rax                ; bytes read
        lea     rsi, [rdbuf]
        call    do_write
        lea     rsi, [nl]
        mov     edx, 1
        call    do_write
        mov     eax, SYS_close
        mov     rdi, r12
        syscall

        ; 4. mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        mov     eax, SYS_mmap
        xor     edi, edi
        mov     esi, 4096
        mov     edx, 3                  ; PROT_READ|PROT_WRITE
        mov     r10d, 0x22              ; MAP_PRIVATE|MAP_ANONYMOUS
        mov     r8, -1
        xor     r9d, r9d
        syscall
        cmp     rax, -4095
        ja      .fail                   ; returned -errno
        mov     r13, rax                ; page address
        lea     rsi, [mapmsg]           ; copy text into the new page
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
