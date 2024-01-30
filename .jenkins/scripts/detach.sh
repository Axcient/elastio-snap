#!/bin/bash

TEST_IMAGES=(${TEST_IMAGES})

for test_image in ${TEST_IMAGES[@]}; do
	if virsh domblklist ${BOX_DIR##*/}_${INSTANCE_NAME} --details | grep "file" | awk '{ print $NF }' | grep ${test_image} ; then
		virsh detach-disk --domain ${BOX_DIR##*/}_${INSTANCE_NAME} ${test_image}
	fi
	test -e "${TEST_IMAGE}" && rm -f ${TEST_IMAGE}
done

exit 0 #NOTE: never fail