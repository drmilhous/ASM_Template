# GNU as (AT&T syntax) AVX examples for Linux, macOS (Intel) and Windows x64 (MSYS2/MinGW).
#   make                     build all six         make 02_vector_add_avx    build one
#   ./02_vector_add_avx      run it                make clean
# The sources are .S files: gcc/clang run the C preprocessor (platform.h), then GNU as.
# Run 05_cpuid_detect first: examples 02-06 need a CPU with the matching extension.
PROGS = 01_vector_add_sse 02_vector_add_avx 03_dot_product_fma 04_avx2_integer_sum 05_cpuid_detect 06_avx512_mask

UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
  EXE =
  ASFLAGS_DBG = -g
else ifeq ($(UNAME),Darwin)
  EXE =
  ASFLAGS_DBG = -g
else
  EXE = .exe             # MSYS2 / MinGW / Git Bash on Windows
  ASFLAGS_DBG = -g
endif
CC ?= gcc
# For a cross build from Linux: make EXE=.exe CC=x86_64-w64-mingw32-gcc

.PHONY: all clean
all: $(PROGS:%=%$(EXE))

%$(EXE): %.S platform.h
	$(CC) $(ASFLAGS_DBG) -c $< -o $*.o
	$(CC) $*.o -o $@

clean:
	rm -f $(PROGS) $(PROGS:%=%.exe) *.o
