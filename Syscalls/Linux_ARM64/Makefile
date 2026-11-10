# Native on an ARM64 Linux box.  Cross-building: make AS=aarch64-linux-gnu-as LD=aarch64-linux-gnu-ld
AS ?= as
LD ?= ld
all: syscalls
syscalls: syscalls.o
	$(LD) -o $@ $+
syscalls.o: syscalls.s
	$(AS) syscalls.s -o $@
clean:
	rm -f syscalls *.o
