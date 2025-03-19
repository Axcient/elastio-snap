// SPDX-License-Identifier: GPL-2.0-only

/*
 * Copyright (C) 2025 Axcient Inc.
 */

#include "includes.h"
MODULE_LICENSE("GPL");

static inline void dummy(void){
	struct block_device *bd = NULL;
	blkdev_issue_flush(bd, GFP_KERNEL, NULL);
}
