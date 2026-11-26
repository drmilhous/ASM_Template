PYTHON ?= python3
ARCH_FLAG = $(if $(ARCH),--arch $(ARCH),)
.PHONY: all test
all:
	$(PYTHON) build.py $(ARCH_FLAG)
test:
	$(PYTHON) build.py $(ARCH_FLAG) --test
