all: syscalls
syscalls: syscalls.o
	ld -m elf_i386 -o $@ $+
syscalls.o: syscalls.asm
	nasm -f elf32 syscalls.asm -o $@
clean:
	rm -f syscalls *.o
