; Linux x86 (32-bit) raw system calls (no libc).  Build: make   Run: ./syscalls
; Convention: syscall number in EAX, args in EBX, ECX, EDX, ESI, EDI, EBP.
;             Execute "int 0x80".  Result in EAX (-4095..-1 means -errno).
; Numbers: exit=1 read=3 write=4 open=5 close=6 getpid=20 munmap=91 mmap2=192
; (mmap2 takes its file offset in 4096-byte pages; old "mmap"=90 takes a struct pointer.)

SYS_exit   equ 1
SYS_read   equ 3
SYS_write  equ 4
SYS_open   equ 5
SYS_close  equ 6
SYS_getpid equ 20
SYS_munmap equ 91
SYS_mmap2  equ 192

segment .data
msg:     db "1. write: Hello from a raw Linux x86 syscall", 10
msg_len  equ $ - msg
pidmsg:  db "2. getpid: "
pidmsg_len equ $ - pidmsg
filemsg: db "3. open/read/close /etc/hosts (first 40 bytes):", 10
filemsg_len equ $ - filemsg
mapmsg:  db "4. mmap2: wrote this text into an anonymous page", 10
mapmsg_len equ $ - mapmsg
path:    db "/etc/hosts", 0
nl:      db 10

segment .bss
numbuf:  resb 24
rdbuf:   resb 40

segment .text
global _start

; write(1, ecx, edx)
do_write:
        mov     ebx, 1
        mov     eax, SYS_write
        int     0x80
        ret

; print EDI as decimal + newline
print_dec:
        mov     ecx, numbuf + 20
        mov     byte [ecx], 10
        mov     eax, edi
        mov     esi, 10
.next:  xor     edx, edx
        div     esi
        add     dl, '0'
        dec     ecx
        mov     [ecx], dl
        test    eax, eax
        jnz     .next
        mov     edx, numbuf + 21
        sub     edx, ecx
        jmp     do_write

_start:
        ; 1. write
        mov     ecx, msg
        mov     edx, msg_len
        call    do_write

        ; 2. getpid
        mov     ecx, pidmsg
        mov     edx, pidmsg_len
        call    do_write
        mov     eax, SYS_getpid
        int     0x80
        mov     edi, eax
        call    print_dec

        ; 3. open / read / write / close
        mov     ecx, filemsg
        mov     edx, filemsg_len
        call    do_write
        mov     eax, SYS_open
        mov     ebx, path
        xor     ecx, ecx                ; O_RDONLY
        xor     edx, edx
        int     0x80
        test    eax, eax
        js      .fail
        mov     ebp, eax                ; fd
        mov     eax, SYS_read
        mov     ebx, ebp
        mov     ecx, rdbuf
        mov     edx, 40
        int     0x80
        test    eax, eax
        js      .fail
        mov     edx, eax
        mov     ecx, rdbuf
        call    do_write
        mov     ecx, nl
        mov     edx, 1
        call    do_write
        mov     eax, SYS_close
        mov     ebx, ebp
        int     0x80

        ; 4. mmap2(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        mov     eax, SYS_mmap2
        xor     ebx, ebx
        mov     ecx, 4096
        mov     edx, 3
        mov     esi, 0x22
        mov     edi, -1
        xor     ebp, ebp
        int     0x80
        cmp     eax, -4095
        ja      .fail
        mov     ebp, eax                ; page address
        mov     esi, mapmsg
        mov     edi, ebp
        mov     ecx, mapmsg_len
        cld
        rep movsb
        mov     ecx, ebp
        mov     edx, mapmsg_len
        call    do_write
        mov     eax, SYS_munmap
        mov     ebx, ebp
        mov     ecx, 4096
        int     0x80

        ; 5. exit(0)
        xor     ebx, ebx
        mov     eax, SYS_exit
        int     0x80
.fail:
        mov     ebx, 1
        mov     eax, SYS_exit
        int     0x80
