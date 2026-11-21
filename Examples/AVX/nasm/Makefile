# NASM (Intel syntax) AVX examples for Linux, macOS (Intel) and Windows x64 (MSYS2/MinGW).
#   make                     build all six         make 02_vector_add_avx    build one
#   ./02_vector_add_avx      run it                make clean
# Windows with Visual Studio instead of MinGW: use .\quickBuild.ps1 (see README.md).
# Run 05_cpuid_detect first: examples 02-06 need a CPU with the matching extension.
PROGS = 01_vector_add_sse 02_vector_add_avx 03_dot_product_fma 04_avx2_integer_sum 05_cpuid_detect 06_avx512_mask

UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
  FMT = elf64
  EXE =
  NASMFLAGS = -g -F dwarf
else ifeq ($(UNAME),Darwin)
  FMT = macho64
  EXE =
  NASMFLAGS =
else
  FMT = win64            # MSYS2 / MinGW / Git Bash on Windows
  EXE = .exe
  NASMFLAGS =
endif
CC ?= gcc
# For a cross build from Linux: make FMT=win64 EXE=.exe CC=x86_64-w64-mingw32-gcc

.PHONY: all clean
all: $(PROGS:%=%$(EXE))

%$(EXE): %.asm platform.inc
	nasm -f $(FMT) $(NASMFLAGS) $< -o $*.o
	$(CC) $*.o -o $@

clean:
	rm -f $(PROGS) $(PROGS:%=%.exe) *.o
