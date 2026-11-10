all: libc_calls
libc_calls: libc_calls.o
	gcc -z noexecstack -o $@ $+
libc_calls.o: libc_calls.asm
	nasm -f elf64 libc_calls.asm -o $@
clean:
	rm -f libc_calls *.o
