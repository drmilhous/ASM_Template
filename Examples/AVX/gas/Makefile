# GNU as (ARM64, NEON) examples for Linux ARM64, macOS (Apple Silicon) and Windows ARM64.
# They are ASM_Template programs: asm_main + the template's ARM io library + its driver.c.
#   make                     build all seven       make 03_dot_product_fmla    build one
#   ./03_dot_product_fmla    run it                make clean
# The sources are .S files: the compiler driver runs the C preprocessor (platform.h), then the
# GNU-syntax assembler (gas on Linux, the built-in clang assembler on macOS and Windows).
# Windows: run this from an MSYS2 CLANGARM64 shell, or use .\quickBuild.ps1 (see ../README.md).
# Run 05_feature_detect first: 07_sve_predicate needs an SVE CPU (it checks and says so).
PROGS = 01_vector_add_neon 02_vector_add_pairs 03_dot_product_fmla 04_integer_sum 05_feature_detect 06_masked_tail 07_sve_predicate

# The template folder (override with: make T=/path/to/ASM_Template, or set ASM_TEMPLATE_HOME)
T ?= $(if $(ASM_TEMPLATE_HOME),$(ASM_TEMPLATE_HOME),$(abspath ../../..))

UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
  EXE =
  LIB = $(T)/64_Bit_ARM
  IOSRC = $(LIB)/io.s
  DRIVER = $(LIB)/driver.c
  LDFLAGS = -z noexecstack
else ifeq ($(UNAME),Darwin)
  EXE =
  LIB = $(T)/M1_Mac
  IOSRC = $(LIB)/io_arm.s
  DRIVER = $(LIB)/driver_arm.c
  LDFLAGS =
  CC = clang -arch arm64
else
  EXE = .exe             # MSYS2 CLANGARM64 / Git Bash on Windows ARM64
  LIB = $(T)/64_Bit_Windows_ARM
  IOSRC = $(LIB)/io_c_fallback.c
  DRIVER = $(LIB)/driver.c
  LDFLAGS =
  CC = clang
endif
# For a cross build from an x86 Linux machine (then run with: qemu-aarch64 -cpu max -L /usr/aarch64-linux-gnu ./prog):
#   make CC=aarch64-linux-gnu-gcc

.PHONY: all clean
all: $(PROGS:%=%$(EXE))

io.o: $(IOSRC)
	$(CC) -c $< -o $@

%$(EXE): %.S platform.h io.o
	$(CC) -g -c $< -o $*.o
	$(CC) $(LDFLAGS) -o $@ $*.o io.o $(DRIVER)

clean:
	rm -f $(PROGS) $(PROGS:%=%.exe) *.o
