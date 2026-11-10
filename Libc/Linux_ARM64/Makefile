# Native ARM64 Linux.  Cross-build on x86: make CC=aarch64-linux-gnu-gcc  (run with: qemu-aarch64 -L /usr/aarch64-linux-gnu ./libc_calls)
CC ?= gcc
all: libc_calls
libc_calls: libc_calls.s
	$(CC) -z noexecstack -o $@ $+
clean:
	rm -f libc_calls *.o
