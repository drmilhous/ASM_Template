; Windows x64: RAW system calls - executing the "syscall" instruction ourselves.
;
; !! Windows system call numbers (SSNs) change between Windows versions and even
; !! between builds, and Microsoft does not document them.  Never hard-code them.
; !! This example finds the number at run time by reading it out of the
; !! ntdll.dll stub, which on x64 always looks like:
; !!       4C 8B D1          mov  r10, rcx
; !!       B8 xx xx 00 00    mov  eax, <SSN>
; !!       0F 05             syscall
; !!       C3                ret
; !! If security software has hooked the stub, the pattern check fails and we
; !! stop with a message instead of guessing.
;
; Convention: SSN in EAX, args as for a normal Win64 call (RCX, RDX, R8, R9, stack),
;             but RCX must be copied to R10 first (the kernel clobbers RCX).
;             Result is an NTSTATUS in EAX (0 = STATUS_SUCCESS).
; Calls shown: NtWriteFile and NtTerminateProcess.  Others (NtOpenFile,
; NtReadFile, NtAllocateVirtualMemory, NtClose ...) work exactly the same way.
; Build + run: .\quickBuild.ps1
default rel
extern GetModuleHandleA
extern GetProcAddress
extern GetStdHandle
extern WriteFile
extern ExitProcess

section .data
ntdll:   db "ntdll.dll", 0
n_write: db "NtWriteFile", 0
n_term:  db "NtTerminateProcess", 0
msg:     db "Hello from a raw Windows x64 syscall (NtWriteFile)", 13, 10
msg_len  equ $ - msg
hookmsg: db "ntdll stub does not look like a plain syscall stub (hooked?)", 13, 10
hookmsg_len equ $ - hookmsg

section .bss
hOut:      resq 1
ssn_write: resd 1
ssn_term:  resd 1
iosb:      resq 2                       ; IO_STATUS_BLOCK {Status, Information}
count:     resd 1

section .text
global start

; do_syscall: EAX = SSN; arguments laid out exactly as for a normal Win64 call.
do_syscall:
        mov     r10, rcx
        syscall
        ret

; get_ssn: RCX = module handle, RDX = function name.  Returns EAX = SSN, or -1.
get_ssn:
        sub     rsp, 0x28
        call    GetProcAddress          ; RCX/RDX already set up
        add     rsp, 0x28
        test    rax, rax
        jz      .bad
        cmp     dword [rax], 0xB8D18B4C ; 4C 8B D1 B8 = mov r10,rcx ; mov eax,imm32
        jne     .bad
        mov     eax, [rax + 4]          ; the syscall number
        ret
.bad:   mov     eax, -1
        ret

start:
        sub     rsp, 0x58

        mov     ecx, -11                ; STD_OUTPUT_HANDLE (only used for the error path)
        call    GetStdHandle
        mov     [hOut], rax

        lea     rcx, [ntdll]
        call    GetModuleHandleA
        mov     rbx, rax                ; ntdll base (RBX is callee-saved; we never return)

        mov     rcx, rbx
        lea     rdx, [n_write]
        call    get_ssn
        mov     [ssn_write], eax
        mov     rcx, rbx
        lea     rdx, [n_term]
        call    get_ssn
        mov     [ssn_term], eax
        cmp     dword [ssn_write], -1
        je      .hooked
        cmp     dword [ssn_term], -1
        je      .hooked

        ; NtWriteFile(FileHandle, Event, ApcRoutine, ApcContext, IoStatusBlock,
        ;             Buffer, Length, ByteOffset, Key)      -- 9 arguments
        mov     rcx, [hOut]
        xor     edx, edx                ; Event = NULL
        xor     r8d, r8d                ; ApcRoutine = NULL
        xor     r9d, r9d                ; ApcContext = NULL
        lea     rax, [iosb]
        mov     [rsp + 0x20], rax       ; 5th: IoStatusBlock
        lea     rax, [msg]
        mov     [rsp + 0x28], rax       ; 6th: Buffer
        mov     qword [rsp + 0x30], msg_len ; 7th: Length
        mov     qword [rsp + 0x38], 0   ; 8th: ByteOffset = NULL
        mov     qword [rsp + 0x40], 0   ; 9th: Key = NULL
        mov     eax, [ssn_write]
        call    do_syscall

        ; NtTerminateProcess(NtCurrentProcess() = -1, exit status 0)
        mov     rcx, -1
        xor     edx, edx
        mov     eax, [ssn_term]
        call    do_syscall
        ; not reached
.hooked:
        mov     rcx, [hOut]
        lea     rdx, [hookmsg]
        mov     r8d, hookmsg_len
        lea     r9, [count]
        mov     qword [rsp + 0x20], 0
        call    WriteFile
        mov     ecx, 1
        call    ExitProcess
