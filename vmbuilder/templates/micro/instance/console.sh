#!/bin/sh
#
# disable console blanking, we're using a VM not a real computer...
#
for index in $(seq 1 6)
do
	setterm -blank 0 -powerdown 0 -powersave off > /dev/tty${index}
done
