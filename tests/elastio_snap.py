# SPDX-License-Identifier: GPL-2.0-only

#
# Copyright (C) 2019 Datto, Inc.
# Additional contributions by Elastio Software, Inc are Copyright (C) 2020 Elastio Software Inc.
#

from cffi import FFI
import os
import math
import util
import time
import errno
import json

ffi = FFI()

ffi.cdef("""
#define COW_UUID_SIZE 16
#define PATH_MAX 4096

//macros for defining the flags
#define COW_ON_BDEV 1

//macros for defining the state of a tracing struct (bit offsets)
#define SNAPSHOT 0
#define ACTIVE 1
#define UNVERIFIED 2

struct elastio_snap_info {
    unsigned int minor;
    unsigned int flags;
    unsigned long state;
    int error;
    unsigned long cache_size;
    unsigned long long falloc_size;
    unsigned long long seqid;
    char uuid[COW_UUID_SIZE];
    char cow[PATH_MAX];
    char bdev[PATH_MAX];
    unsigned long long version;
    unsigned long long nr_changed_blocks;
    bool ignore_snap_errors;
};

int elastio_snap_setup_snapshot(unsigned int minor, char *bdev, char *cow, unsigned long fallocated_space, unsigned long cache_size, bool ignore_snap_errors);
int elastio_snap_reload_snapshot(unsigned int minor, char *bdev, char *cow, unsigned long cache_size, bool ignore_snap_errors);
int elastio_snap_reload_incremental(unsigned int minor, char *bdev, char *cow, unsigned long cache_size, bool ignore_snap_errors);
int elastio_snap_destroy(unsigned int minor);
int elastio_snap_transition_incremental(unsigned int minor);
int elastio_snap_transition_snapshot(unsigned int minor, char *cow, unsigned long fallocated_space);
int elastio_snap_reconfigure(unsigned int minor, unsigned long cache_size);
int elastio_snap_info(unsigned int minor, struct elastio_snap_info *info);
int elastio_snap_get_free_minor(void);
""")


class Flags:
    COW_ON_BDEV = 2


lib = ffi.dlopen("../lib/libelastio-snap.so")


# It could be "class State(IntFlag):", but "IntFlag" was introduced in class "enum" of the Python 3.6,
# which isn't present on Debian 9 and CentOS 7.
class State:
    SNAPSHOT = 1
    ACTIVE = 2

def get_dev_by_minor(minor):
    print("Minor received: {}".format(minor))
    with open('/proc/elastio-snap-info', 'r') as file:
        data = json.load(file)

    devices = data['devices']
    for i in range(len(devices)):
        if minor == devices[i]['minor']:
            return devices[i]['block_device']


def get_cow_file(minor):
    print("Minor received: {}".format(minor))
    with open('/proc/elastio-snap-info', 'r') as file:
        data = json.load(file)

    devices = data['devices']
    for i in range(len(devices)):
        if minor == devices[i]['minor']:
            print(devices[i])
            return devices[i]['cow_file']

def cow_preallocate(device, fallocated_space, cow_file):
    if fallocated_space == 0:
        page_size = util.os_page_size()
        cow_file_size_factor = 0.1  # 10% by default if `fallocated_space` is 0
        cow_file_size = util.dev_size_bytes(device) * cow_file_size_factor

        # rounding up aligned to the PAGE_SIZE
        cow_file_size = int(math.ceil(cow_file_size / page_size) * page_size)
        fallocated_space = (int) (cow_file_size / 1024 / 1024)
        print("Opening cow file {}".format(cow_file))
        with open(cow_file, "wb") as file:
            file.seek(fallocated_space * 1024 * 1024 - 1)
            file.write(b"\0")


def setup(minor, device, cow_file, fallocated_space=0, cache_size=0, ignore_snap_errors=False):
    cow_preallocate(device, fallocated_space, cow_file)

    ret = lib.elastio_snap_setup_snapshot(
        minor,
        device.encode("utf-8"),
        cow_file.encode("utf-8"),
        fallocated_space,
        cache_size,
        ignore_snap_errors
    )

    if ret != 0:
        return ffi.errno

    util.settle()
    return 0


def reload_snapshot(minor, device, cow_file, cache_size=0, ignore_snap_errors=False):
    ret = lib.elastio_snap_reload_snapshot(
        minor,
        device.encode("utf-8"),
        cow_file.encode("utf-8"),
        cache_size,
        ignore_snap_errors
    )

    if ret != 0:
        return ffi.errno

    util.settle()
    return 0


def reload_incremental(minor, device, cow_file, cache_size=0, ignore_snap_errors=False):
    ret = lib.elastio_snap_reload_incremental(
        minor,
        device.encode("utf-8"),
        cow_file.encode("utf-8"),
        cache_size,
        ignore_snap_errors
    )

    if ret != 0:
        return ffi.errno

    util.settle()
    return 0


def destroy(minor, retries=3):
    for retry in range(retries):
        ret = lib.elastio_snap_destroy(minor)
        if ret == 0:
            util.settle()
            return 0
        else:
            if ffi.errno == errno.EBUSY:
                print('Retry {} of {}: couldn\'t destroy device (minor {})'. format(retry + 1, retries, minor))
                time.sleep(1)
            else:
                break

    return ffi.errno


def transition_to_incremental(minor):
    ret = lib.elastio_snap_transition_incremental(minor)
    if ret != 0:
        return ffi.errno

    util.settle()
    return 0


def transition_to_snapshot(minor, cow_file, fallocated_space=0):
    cow_preallocate(get_dev_by_minor(minor), fallocated_space, cow_file)

    ret = lib.elastio_snap_transition_snapshot(
        minor,
        cow_file.encode("utf-8"),
        fallocated_space
    )

    if ret != 0:
        return ffi.errno

    util.settle()
    return 0


def reconfigure(minor, cache_size):
    ret = lib.elastio_snap_reconfigure(minor, cache_size)
    if ret != 0:
        return ffi.errno

    util.settle()
    return 0


def info(minor):
    di = ffi.new("struct elastio_snap_info *")
    ret = lib.elastio_snap_info(minor, di)
    if ret != 0:
        return None

    # bytes.hex() is not available in Python <3.5
    uuid = "".join(map(lambda b: format(b, "02x"), ffi.string(di.uuid)))

    return {
        "minor": minor,
        "flags": di.flags,
        "state": di.state,
        "error": di.error,
        "cache_size": di.cache_size,
        "falloc_size": di.falloc_size,
        "uuid": uuid,
        "cow": ffi.string(di.cow).decode("utf-8"),
        "bdev": ffi.string(di.bdev).decode("utf-8"),
        "version": di.version,
        "nr_changed_blocks": di.nr_changed_blocks,
        "ignore_snap_errors": di.ignore_snap_errors
    }


def get_free_minor():
    ret = lib.elastio_snap_get_free_minor()
    if (ret < 0):
        return -ffi.errno
    return ret


def version():
    with open("/sys/module/elastio-snap/version", "r") as v:
        return v.read().strip()
