// Linux AArch64 raw system calls (no libc), GNU as syntax.  Build: make   Run: ./syscalls
// Convention: syscall number in X8, args in X0..X5, execute "svc #0".
//             Result in X0 (-4095..-1 means -errno).
// Numbers (generic table; there is NO "open", use openat):
//   openat=56 close=57 read=63 write=64 exit=93 getpid=172 munmap=215 mmap=222
        .equ SYS_openat, 56
        .equ SYS_close,  57
        .equ SYS_read,   63
        .equ SYS_write,  64
        .equ SYS_exit,   93
        .equ SYS_getpid, 172
        .equ SYS_munmap, 215
        .equ SYS_mmap,   222
        .equ AT_FDCWD,   -100

        .data
msg:      .ascii "1. write: Hello from a raw Linux ARM64 syscall\n"
        .equ msg_len, . - msg
pidmsg:   .ascii "2. getpid: "
        .equ pidmsg_len, . - pidmsg
filemsg:  .ascii "3. openat/read/close /etc/hosts (first 40 bytes):\n"
        .equ filemsg_len, . - filemsg
mapmsg:   .ascii "4. mmap: wrote this text into an anonymous page\n"
        .equ mapmsg_len, . - mapmsg
path:     .asciz "/etc/hosts"
nl:       .ascii "\n"

        .bss
numbuf:   .skip 24
rdbuf:    .skip 40

        .text
        .global _start

// do_write: x1 = buffer, x2 = length.  write(1, x1, x2)
do_write:
        mov     x0, #1
        mov     x8, #SYS_write
        svc     #0
        ret

// print_dec: x0 = value; prints decimal + newline
print_dec:
        mov     x9, x30                 // save return address (do_write is a leaf)
        adrp    x1, numbuf
        add     x1, x1, :lo12:numbuf
        add     x1, x1, #20
        mov     w3, #10
        strb    w3, [x1]                // newline at the end
        add     x4, x1, #1              // end of text
        mov     x5, #10
1:      udiv    x6, x0, x5
        msub    x7, x6, x5, x0          // remainder
        add     w7, w7, #'0'
        sub     x1, x1, #1
        strb    w7, [x1]
        mov     x0, x6
        cbnz    x0, 1b
        sub     x2, x4, x1
        mov     x30, x9
        b       do_write                // tail call

_start:
        // 1. write
        adrp    x1, msg
        add     x1, x1, :lo12:msg
        mov     x2, #msg_len
        bl      do_write

        // 2. getpid
        adrp    x1, pidmsg
        add     x1, x1, :lo12:pidmsg
        mov     x2, #pidmsg_len
        bl      do_write
        mov     x8, #SYS_getpid
        svc     #0
        bl      print_dec

        // 3. openat / read / write / close
        adrp    x1, filemsg
        add     x1, x1, :lo12:filemsg
        mov     x2, #filemsg_len
        bl      do_write
        mov     x0, #AT_FDCWD
        adrp    x1, path
        add     x1, x1, :lo12:path
        mov     x2, #0                  // O_RDONLY
        mov     x3, #0
        mov     x8, #SYS_openat
        svc     #0
        tbnz    x0, #63, fail
        mov     x19, x0                 // fd
        adrp    x1, rdbuf
        add     x1, x1, :lo12:rdbuf
        mov     x2, #40
        mov     x8, #SYS_read
        svc     #0
        tbnz    x0, #63, fail
        mov     x2, x0
        adrp    x1, rdbuf
        add     x1, x1, :lo12:rdbuf
        bl      do_write
        adrp    x1, nl
        add     x1, x1, :lo12:nl
        mov     x2, #1
        bl      do_write
        mov     x0, x19
        mov     x8, #SYS_close
        svc     #0

        // 4. mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        mov     x0, #0
        mov     x1, #4096
        mov     x2, #3
        mov     x3, #0x22
        mov     x4, #-1
        mov     x5, #0
        mov     x8, #SYS_mmap
        svc     #0
        cmn     x0, #4095               // x0 >= -4095 (unsigned) means error
        b.hi    fail
        mov     x20, x0                 // page address
        adrp    x1, mapmsg
        add     x1, x1, :lo12:mapmsg
        mov     x2, #mapmsg_len
        mov     x3, x20
2:      ldrb    w4, [x1], #1            // copy text into the new page
        strb    w4, [x3], #1
        subs    x2, x2, #1
        b.ne    2b
        mov     x1, x20
        mov     x2, #mapmsg_len
        bl      do_write
        mov     x0, x20
        mov     x1, #4096
        mov     x8, #SYS_munmap
        svc     #0

        // 5. exit(0)
        mov     x0, #0
        mov     x8, #SYS_exit
        svc     #0
fail:
        mov     x0, #1
        mov     x8, #SYS_exit
        svc     #0
