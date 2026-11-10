# Apple silicon Mac with Xcode command line tools.
# (clang ad-hoc signs the program. If step 4 fails with a hardened runtime, the program
# needs the com.apple.security.cs.allow-jit entitlement.)
all: libc_calls
libc_calls: libc_calls.s
	clang -arch arm64 -o $@ $+
clean:
	rm -f libc_calls *.o
