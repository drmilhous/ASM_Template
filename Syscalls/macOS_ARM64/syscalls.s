// macOS Apple-silicon (arm64) raw BSD system calls.  Apple "as"/clang syntax.
// Build: make   Run: ./syscalls
// Convention: syscall number in X16, args in X0..X7, execute "svc #0x80".
//             On error the CARRY flag is set and X0 holds the (positive) errno.
//             (On x86-64 macOS the number needs the 0x2000000 BSD class prefix;
//              on arm64 the plain BSD number is used.)
// Numbers: exit=1 read=3 write=4 open=5 close=6 getpid=20 munmap=73 mmap=197
// Apple warns that raw syscalls are not a stable ABI; libSystem (the C library)
// is the supported interface.  We still link libSystem because dyld requires it.
        .set SYS_exit,   1
        .set SYS_read,   3
        .set SYS_write,  4
        .set SYS_open,   5
        .set SYS_close,  6
        .set SYS_getpid, 20
        .set SYS_munmap, 73
        .set SYS_mmap,   197

        .section __DATA,__data
msg:      .ascii "1. write: Hello from a raw macOS ARM64 syscall\n"
        .set msg_len, . - msg
pidmsg:   .ascii "2. getpid: "
        .set pidmsg_len, . - pidmsg
filemsg:  .ascii "3. open/read/close /etc/hosts (first 40 bytes):\n"
        .set filemsg_len, . - filemsg
mapmsg:   .ascii "4. mmap: wrote this text into an anonymous page\n"
        .set mapmsg_len, . - mapmsg
path:     .asciz "/etc/hosts"
nl:       .ascii "\n"
numbuf:   .space 24
rdbuf:    .space 40

        .text
        .globl _start
        .p2align 2

// do_write: x1 = buffer, x2 = length.  write(1, x1, x2)
do_write:
        mov     x0, #1
        mov     x16, #SYS_write
        svc     #0x80
        ret

// print_dec: x0 = value; prints decimal + newline
print_dec:
        mov     x9, x30
        adrp    x1, numbuf@PAGE
        add     x1, x1, numbuf@PAGEOFF
        add     x1, x1, #20
        mov     w3, #10
        strb    w3, [x1]
        add     x4, x1, #1
        mov     x5, #10
1:      udiv    x6, x0, x5
        msub    x7, x6, x5, x0
        add     w7, w7, #'0'
        sub     x1, x1, #1
        strb    w7, [x1]
        mov     x0, x6
        cbnz    x0, 1b
        sub     x2, x4, x1
        mov     x30, x9
        b       do_write

_start:
        // 1. write
        adrp    x1, msg@PAGE
        add     x1, x1, msg@PAGEOFF
        mov     x2, #msg_len
        bl      do_write

        // 2. getpid
        adrp    x1, pidmsg@PAGE
        add     x1, x1, pidmsg@PAGEOFF
        mov     x2, #pidmsg_len
        bl      do_write
        mov     x16, #SYS_getpid
        svc     #0x80
        bl      print_dec

        // 3. open / read / write / close
        adrp    x1, filemsg@PAGE
        add     x1, x1, filemsg@PAGEOFF
        mov     x2, #filemsg_len
        bl      do_write
        adrp    x0, path@PAGE
        add     x0, x0, path@PAGEOFF
        mov     x1, #0                  // O_RDONLY
        mov     x2, #0
        mov     x16, #SYS_open
        svc     #0x80
        b.cs    fail
        mov     x19, x0                 // fd
        adrp    x1, rdbuf@PAGE
        add     x1, x1, rdbuf@PAGEOFF
        mov     x2, #40
        mov     x16, #SYS_read
        svc     #0x80
        b.cs    fail
        mov     x2, x0
        adrp    x1, rdbuf@PAGE
        add     x1, x1, rdbuf@PAGEOFF
        bl      do_write
        adrp    x1, nl@PAGE
        add     x1, x1, nl@PAGEOFF
        mov     x2, #1
        bl      do_write
        mov     x0, x19
        mov     x16, #SYS_close
        svc     #0x80

        // 4. mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0)
        //    (macOS: MAP_PRIVATE=0x2, MAP_ANON=0x1000; Apple silicon pages are 16 KB,
        //     so ask for 16384 to be safe)
        mov     x0, #0
        mov     x1, #16384
        mov     x2, #3
        mov     x3, #0x1002
        mov     x4, #-1
        mov     x5, #0
        mov     x16, #SYS_mmap
        svc     #0x80
        b.cs    fail
        mov     x20, x0                 // page address
        adrp    x1, mapmsg@PAGE
        add     x1, x1, mapmsg@PAGEOFF
        mov     x2, #mapmsg_len
        mov     x3, x20
2:      ldrb    w4, [x1], #1
        strb    w4, [x3], #1
        subs    x2, x2, #1
        b.ne    2b
        mov     x1, x20
        mov     x2, #mapmsg_len
        bl      do_write
        mov     x0, x20
        mov     x1, #16384
        mov     x16, #SYS_munmap
        svc     #0x80

        // 5. exit(0)
        mov     x0, #0
        mov     x16, #SYS_exit
        svc     #0x80
fail:
        mov     x0, #1
        mov     x16, #SYS_exit
        svc     #0x80
