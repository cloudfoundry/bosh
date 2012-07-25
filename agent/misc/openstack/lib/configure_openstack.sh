#!/bin/bash
#
# Copyright (c) 2009-2012 VMware, Inc.

update-rc.d -f hwclockfirst remove
update-rc.d -f hwclock remove

# Remove the network persistence rules
rm -rf /etc/udev/rules.d/70-persistent-net.rules

# lp450463
echo "acpiphp" >> /etc/modules

# configure label for grub(set in stemcell.rake)
sed -i -e "s,root=/dev/hda1,root=LABEL=stemcell_root," /boot/grub/menu.lst