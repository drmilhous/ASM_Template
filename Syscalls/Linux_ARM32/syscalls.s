@ Linux ARM (32-bit, EABI) raw system calls (no libc), GNU as syntax.
@ Build: make   Run: ./syscalls
@ Convention: syscall number in R7, args in R0..R6, execute "svc #0".
@             Result in R0 (-4095..-1 means -errno).
@ Numbers: exit=1 read=3 write=4 open=5 close=6 getpid=20 munmap=91 mmap2=192
@ (same table as 32-bit x86).  Uses udiv, so it needs ARMv7 with the divide
@ extension (Raspberry Pi 2 and later, or qemu-arm).
        .arch armv7-a
        .arch_extension idiv
        .equ SYS_exit,   1
        .equ SYS_read,   3
        .equ SYS_write,  4
        .equ SYS_open,   5
        .equ SYS_close,  6
        .equ SYS_getpid, 20
        .equ SYS_munmap, 91
        .equ SYS_mmap2,  192

        .data
msg:      .ascii "1. write: Hello from a raw Linux ARM32 syscall\n"
        .equ msg_len, . - msg
pidmsg:   .ascii "2. getpid: "
        .equ pidmsg_len, . - pidmsg
filemsg:  .ascii "3. open/read/close /etc/hosts (first 40 bytes):\n"
        .equ filemsg_len, . - filemsg
mapmsg:   .ascii "4. mmap2: wrote this text into an anonymous page\n"
        .equ mapmsg_len, . - mapmsg
path:     .asciz "/etc/hosts"
nl:       .ascii "\n"

        .bss
        .align 2
numbuf:   .skip 24
rdbuf:    .skip 40

        .text
        .global _start

@ do_write: r1 = buffer, r2 = length.  write(1, r1, r2)
do_write:
        mov     r0, #1
        mov     r7, #SYS_write
        svc     #0
        bx      lr

@ print_dec: r0 = value; prints decimal + newline
print_dec:
        mov     r9, lr
        ldr     r1, =numbuf
        add     r1, r1, #20
        mov     r3, #10
        strb    r3, [r1]                @ newline at the end
        add     r4, r1, #1              @ end of text
        mov     r5, #10
1:      udiv    r6, r0, r5
        mls     r3, r6, r5, r0          @ remainder = r0 - r6*10
        add     r3, r3, #'0'
        sub     r1, r1, #1
        strb    r3, [r1]
        movs    r0, r6
        bne     1b
        sub     r2, r4, r1
        mov     lr, r9
        b       do_write

_start:
        @ 1. write
        ldr     r1, =msg
        mov     r2, #msg_len
        bl      do_write

        @ 2. getpid
        ldr     r1, =pidmsg
        mov     r2, #pidmsg_len
        bl      do_write
        mov     r7, #SYS_getpid
        svc     #0
        bl      print_dec

        @ 3. open / read / write / close
        ldr     r1, =filemsg
        mov     r2, #filemsg_len
        bl      do_write
        ldr     r0, =path
        mov     r1, #0                  @ O_RDONLY
        mov     r2, #0
        mov     r7, #SYS_open
        svc     #0
        cmp     r0, #0
        blt     fail
        mov     r8, r0                  @ fd
        ldr     r1, =rdbuf
        mov     r2, #40
        mov     r7, #SYS_read
        svc     #0
        cmp     r0, #0
        blt     fail
        mov     r2, r0
        ldr     r1, =rdbuf
        bl      do_write
        ldr     r1, =nl
        mov     r2, #1
        bl      do_write
        mov     r0, r8
        mov     r7, #SYS_close
        svc     #0

        @ 4. mmap2(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        mov     r0, #0
        ldr     r1, =4096
        mov     r2, #3
        mov     r3, #0x22
        mvn     r4, #0                  @ fd = -1
        mov     r5, #0                  @ offset (in pages)
        mov     r7, #SYS_mmap2
        svc     #0
        cmn     r0, #4096               @ carry set if r0 >= -4096 (unsigned) = -errno
        bcs     fail
        mov     r10, r0                 @ page address
        ldr     r1, =mapmsg
        mov     r2, #mapmsg_len
        mov     r3, r10
2:      ldrb    r4, [r1], #1            @ copy text into the new page
        strb    r4, [r3], #1
        subs    r2, r2, #1
        bne     2b
        mov     r1, r10
        mov     r2, #mapmsg_len
        bl      do_write
        mov     r0, r10
        ldr     r1, =4096
        mov     r7, #SYS_munmap
        svc     #0

        @ 5. exit(0)
        mov     r0, #0
        mov     r7, #SYS_exit
        svc     #0
fail:
        mov     r0, #1
        mov     r7, #SYS_exit
        svc     #0
