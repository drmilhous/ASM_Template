PYTHON ?= python3
# Native architecture by default; override with: make ARCH=x64 test
ARCH_FLAG = $(if $(ARCH),--arch $(ARCH),)
.PHONY: all test
all:
	$(PYTHON) build.py $(ARCH_FLAG)
test:
	$(PYTHON) build.py $(ARCH_FLAG) --test
