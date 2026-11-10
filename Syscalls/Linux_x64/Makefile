all: syscalls
syscalls: syscalls.o
	ld -o $@ $+
syscalls.o: syscalls.asm
	nasm -f elf64 syscalls.asm -o $@
clean:
	rm -f syscalls *.o
