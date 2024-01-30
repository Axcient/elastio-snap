#!/bin/bash

PWD=$( dirname "${BASH_SOURCE[0]}" )
BOX_DIR=${BOX_DIR:-${PWD}/../buildbox}
INSTANCE_NAME=${1:-${INSTANCE_NAME}}

cd "$BOX_DIR"


SZ="2200M"
ARCH=$(uname -m)
TEST_IMAGES=(${TEST_IMAGES})
TEST_DRIVES=(${TEST_DRIVES})

[ ${ARCH} != "x86_64" ] && VIRSH_FLAGS="--config" || true

for i in ${!TEST_IMAGES[*]}; do
	qemu-img create -f qcow2 ${TEST_IMAGES[i]} $SZ
	virsh attach-disk --domain ${BOX_DIR##*/}_${INSTANCE_NAME} --source ${TEST_IMAGES[i]} --target ${TEST_DRIVES[i]} --driver qemu --subdriver qcow2 --targetbus virtio ${VIRSH_FLAGS-}
done

# ARM64 boxes don't support "hot plug" w/o reboot
if [ ${ARCH} != "x86_64" ]; then
	virsh destroy --domain ${BOX_DIR##*/}_${INSTANCE_NAME}
	virsh start --domain ${BOX_DIR##*/}_${INSTANCE_NAME}
	while ! vagrant ssh ${INSTANCE_NAME} -c 'uptime'; do
		echo "Waiting..."
		sleep 1
	done
fi

for drive in ${TEST_DRIVES[@]}; do
	vagrant ssh ${INSTANCE_NAME} -c "echo -e \"n\\np\\n\\n\\n\\nw\" | sudo fdisk /dev/$drive"
done