# Run on a Mac with Apple silicon (Xcode command line tools installed).
SDK = $(shell xcrun -sdk macosx --show-sdk-path)
all: syscalls
syscalls: syscalls.o
	ld -o $@ $+ -e _start -arch arm64 -lSystem -syslibroot $(SDK)
syscalls.o: syscalls.s
	as -arch arm64 syscalls.s -o $@
clean:
	rm -f syscalls *.o
