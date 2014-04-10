#!/usr/bin/env bash

# rescan-scsi-bus is used only by the ruby agent. This step (and all references to rescan-scsi-bus) can be deleted
# when the ruby agent is no longer supported.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Newer ubuntu releases provide /sbin/rescan-scsi-bus, which is what the agent expects
# Ensure stemcells based on older ubuntu releases will work with the new agent
if [ "${DISTRIB_CODENAME}" == "lucid" ]
then
  cp -p $chroot/sbin/rescan-scsi-bus.sh $chroot/sbin/rescan-scsi-bus
fi
