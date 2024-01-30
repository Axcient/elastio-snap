#!/bin/bash

PWD=$( dirname "${BASH_SOURCE[0]}" )
BOX_DIR=${BOX_DIR:-${PWD}/../buildbox}
INSTANCE_NAME=${1:-${INSTANCE_NAME}}

cd $BOX_DIR

vm_id=$(vagrant global-status --prune | grep $INSTANCE_NAME | cut -d' ' -f1)
# it should never happen, but just in case...
[ ! -z "$vm_id" ] && vagrant destroy $vm_id --force
vagrant up $INSTANCE_NAME
