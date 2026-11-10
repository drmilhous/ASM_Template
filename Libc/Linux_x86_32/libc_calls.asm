; Linux x86 (32-bit): C standard library calls from assembly (cdecl).
; Build: make   Run: ./libc_calls
; Convention: args are PUSHED right-to-left (here: stored at [esp], [esp+4], ...
;             in a block reserved once), result in EAX, the caller removes the args.
;             ESP should be 16-byte aligned at every "call" (modern glibc expects it).
;             Callee-saved: EBX ESI EDI EBP.
; Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
;        3. fork + execv + waitpid (create a process)
;        4. mmap an executable page, copy machine code into it and call it

extern puts, printf, fopen, fwrite, fread, fclose, fflush
extern malloc, free, fork, execv, waitpid, _exit, mmap, munmap

section .data
path:    db "/tmp/libc_demo32.txt", 0
wmode:   db "w", 0
rmode:   db "r", 0
text:    db "written with fwrite", 10
text_len equ $ - text
h1:      db "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose", 0
f1:      db "   read back %d bytes: %s", 0
f2:      db "2. malloc(64) returned %p, stored value %d, now free()", 10, 0
h3:      db "3. fork + execv(/bin/echo) + waitpid", 0
f3:      db "   child %d finished with exit status %d", 10, 0
f4:      db "4. executable page at %p: called generated code, it returned %d", 10, 0
echo:    db "/bin/echo", 0
arg1:    db "   hello from the child process", 0
argv:    dd echo, arg1, 0
; machine code:  mov eax, 42 ; ret
code:    db 0xB8, 42, 0, 0, 0, 0xC3
code_len equ $ - code

section .bss
buf:     resb 64
status:  resd 1

section .text
global main
main:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    esi                     ; entry ESP = 12 mod 16, three pushes -> aligned
        sub     esp, 32                 ; room for outgoing arguments, keeps alignment

        ; 1. stdio
        mov     dword [esp], h1
        call    puts
        mov     dword [esp], path
        mov     dword [esp + 4], wmode
        call    fopen
        test    eax, eax
        jz      .fail
        mov     ebx, eax                ; FILE*
        mov     dword [esp], text       ; fwrite(ptr, size, count, stream)
        mov     dword [esp + 4], 1
        mov     dword [esp + 8], text_len
        mov     [esp + 12], ebx
        call    fwrite
        mov     [esp], ebx
        call    fclose
        mov     dword [esp], path
        mov     dword [esp + 4], rmode
        call    fopen
        test    eax, eax
        jz      .fail
        mov     ebx, eax
        mov     dword [esp], buf        ; fread(ptr, size, count, stream)
        mov     dword [esp + 4], 1
        mov     dword [esp + 8], 63
        mov     [esp + 12], ebx
        call    fread
        mov     esi, eax                ; bytes read
        mov     byte [buf + esi], 0
        mov     [esp], ebx
        call    fclose
        mov     dword [esp], f1
        mov     [esp + 4], esi
        mov     dword [esp + 8], buf
        call    printf

        ; 2. malloc / free
        mov     dword [esp], 64
        call    malloc
        test    eax, eax
        jz      .fail
        mov     ebx, eax
        mov     dword [ebx], 12345
        mov     dword [esp], f2
        mov     [esp + 4], ebx
        mov     eax, [ebx]
        mov     [esp + 8], eax
        call    printf
        mov     [esp], ebx
        call    free

        ; 3. fork / execv / waitpid
        mov     dword [esp], h3
        call    puts
        mov     dword [esp], 0          ; fflush(NULL): the child must not repeat our output
        call    fflush
        call    fork
        test    eax, eax
        js      .fail
        jz      .child
        mov     esi, eax                ; child pid
        mov     [esp], eax
        mov     dword [esp + 4], status
        mov     dword [esp + 8], 0
        call    waitpid
        mov     eax, [status]
        shr     eax, 8
        and     eax, 0xFF               ; WEXITSTATUS
        mov     dword [esp], f3
        mov     [esp + 4], esi
        mov     [esp + 8], eax
        call    printf
        jmp     .exec_page
.child:
        mov     dword [esp], echo
        mov     dword [esp + 4], argv
        call    execv
        mov     dword [esp], 127        ; only reached if execv failed
        call    _exit

        ; 4. executable memory
.exec_page:
        mov     dword [esp], 0          ; mmap(0, 4096, RWX, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        mov     dword [esp + 4], 4096
        mov     dword [esp + 8], 7
        mov     dword [esp + 12], 0x22
        mov     dword [esp + 16], -1
        mov     dword [esp + 20], 0
        call    mmap
        cmp     eax, -1
        je      .fail
        mov     ebx, eax
        mov     esi, code
        mov     edi, ebx
        mov     ecx, code_len
        cld
        rep movsb
        call    ebx                     ; run the generated code
        mov     dword [esp], f4
        mov     [esp + 4], ebx
        mov     [esp + 8], eax
        call    printf
        mov     [esp], ebx
        mov     dword [esp + 4], 4096
        call    munmap

        xor     eax, eax
        jmp     .done
.fail:
        mov     eax, 1
.done:
        add     esp, 32
        pop     esi
        pop     ebx
        pop     ebp
        ret
