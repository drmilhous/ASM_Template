# NASM (Intel syntax) AVX examples for Linux, macOS (Intel) and Windows x64 (MSYS2/MinGW).
# They are ASM_Template programs: asm_main + the template's io.asm library + its driver.c.
#   make                     build all six         make 02_vector_add_avx    build one
#   ./02_vector_add_avx      run it                make clean
# Windows with Visual Studio instead of MinGW: use .\quickBuild.ps1 (see ../README.md).
# Run 05_cpuid_detect first: examples 02-06 need a CPU with the matching extension.
PROGS = 01_vector_add_sse 02_vector_add_avx 03_dot_product_fma 04_avx2_integer_sum 05_cpuid_detect 06_avx512_mask

# The template folder (override with: make T=/path/to/ASM_Template, or set ASM_TEMPLATE_HOME)
T ?= $(if $(ASM_TEMPLATE_HOME),$(ASM_TEMPLATE_HOME),$(abspath ../../..))

UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
  FMT = elf64
  EXE =
  LIB = $(T)/64_Bit_Intel
  DRIVER = driver.c
  NASMFLAGS = -g -F dwarf
  IOFLAGS = -d ELF_TYPE
  LDFLAGS = -z noexecstack
else ifeq ($(UNAME),Darwin)
  FMT = macho64
  EXE =
  LIB = $(T)/M1_Mac
  DRIVER = driver_intel.c
  NASMFLAGS =
  IOFLAGS =
  LDFLAGS =
  # The programs are x86-64, so build them as x86-64 even on an Apple Silicon Mac
  # (plain cc would link for arm64 there). They then run through Rosetta 2.
  CC = clang -target x86_64-apple-macos13.0
else
  CC = gcc
  FMT = win64            # MSYS2 / MinGW / Git Bash on Windows
  EXE = .exe
  LIB = $(T)/64_Bit_Windows
  DRIVER = driver.c
  NASMFLAGS =
  IOFLAGS =
  LDFLAGS =
endif
# For a cross build from Linux:
#   make FMT=win64 EXE=.exe LIB=$(T)/64_Bit_Windows CC=x86_64-w64-mingw32-gcc NASMFLAGS= IOFLAGS= LDFLAGS=

.PHONY: all clean
all: $(PROGS:%=%$(EXE))

io.o: $(LIB)/io.asm
	nasm -f $(FMT) $(IOFLAGS) $< -o $@

%$(EXE): %.asm platform.inc io.o
	nasm -f $(FMT) $(NASMFLAGS) -I$(LIB)/ -I. $< -o $*.o
	$(CC) $(LDFLAGS) -o $@ $*.o io.o $(LIB)/$(DRIVER)

clean:
	rm -f $(PROGS) $(PROGS:%=%.exe) *.o
