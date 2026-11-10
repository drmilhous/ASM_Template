# Native on a 32-bit ARM Linux box.  Cross-building: make AS=arm-linux-gnueabihf-as LD=arm-linux-gnueabihf-ld
AS ?= as
LD ?= ld
all: syscalls
syscalls: syscalls.o
	$(LD) -o $@ $+
syscalls.o: syscalls.s
	$(AS) syscalls.s -o $@
clean:
	rm -f syscalls *.o
