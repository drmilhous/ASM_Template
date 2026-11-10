# Native 32-bit ARM Linux.  Cross-build on x86: make CC=arm-linux-gnueabihf-gcc  (run with: qemu-arm -L /usr/arm-linux-gnueabihf ./libc_calls)
CC ?= gcc
all: libc_calls
libc_calls: libc_calls.s
	$(CC) -no-pie -z noexecstack -o $@ $+
clean:
	rm -f libc_calls *.o
