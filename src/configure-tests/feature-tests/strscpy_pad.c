// SPDX-License-Identifier: GPL-2.0-only

#include "includes.h"
MODULE_LICENSE("GPL");

static inline void dummy(void){
	char dst[16];
	strscpy_pad(dst, "test", sizeof(dst));
}
