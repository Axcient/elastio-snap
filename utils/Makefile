# SPDX-License-Identifier: GPL-2.0-only

INSTALLDIR = $(PREFIX)/bin
SOURCES_UPDATE_IMG = update-img.c
SOURCES_NL_DEBUG = nl_debug.c

.PHONY: all install uninstall clean

all: nl_debug elastio-update-img

nl_debug: $(SOURCES_NL_DEBUG)
	$(CC) $(CCFLAGS) -o $@ $(SOURCES_NL_DEBUG)

elastio-update-img: $(SOURCES_UPDATE_IMG)
	$(CC) $(CCFLAGS) -o $@ -L $(BASE_DIR)/lib $(SOURCES_UPDATE_IMG) -lelastio-snap

install: elastio-update-img
	mkdir -p $(INSTALLDIR)
	install $^ $(INSTALLDIR)

uninstall:
	$(RM) $(INSTALLDIR)/elastio-update-img

clean:
	$(RM) nl_debug
	$(RM) elastio-update-img
