# needs gcc-multilib (sudo apt install gcc-multilib)
all: libc_calls
libc_calls: libc_calls.o
	gcc -m32 -no-pie -z noexecstack -o $@ $+
libc_calls.o: libc_calls.asm
	nasm -f elf32 libc_calls.asm -o $@
clean:
	rm -f libc_calls *.o
