UNSUPPORTED_OLD_GCC_FLAGS := \
	-fzero-call-used-regs=% \
	-ftrivial-auto-var-init=% \
	-Wno-alloc-size-larger-than \
	-Werror=stringop-truncation

KBUILD_CFLAGS := $(filter-out $(UNSUPPORTED_OLD_GCC_FLAGS),$(KBUILD_CFLAGS))
KBUILD_CFLAGS += -Wno-pragmas
