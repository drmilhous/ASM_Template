# Intel Mac, or Apple silicon via Rosetta (clang -arch x86_64).  Needs nasm and Xcode command line tools.
all: libc_calls
libc_calls: libc_calls.o
	clang -arch x86_64 -o $@ $+
libc_calls.o: libc_calls.asm
	nasm -f macho64 libc_calls.asm -o $@
clean:
	rm -f libc_calls *.o
