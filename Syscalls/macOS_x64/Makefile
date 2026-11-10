# Run on an Intel Mac (or Apple silicon via Rosetta) with Xcode command line tools + nasm.
SDK = $(shell xcrun -sdk macosx --show-sdk-path)
all: syscalls
syscalls: syscalls.o
	ld -o $@ $+ -e _start -arch x86_64 -lSystem -syslibroot $(SDK)
syscalls.o: syscalls.asm
	nasm -f macho64 syscalls.asm -o $@
clean:
	rm -f syscalls *.o
