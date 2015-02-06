#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Infrastructure": {
    "DevicePathResolutionType": "scsi",
    "NetworkingType": "manual",

    "Settings": {
      "Sources": [
        {
          "Type": "CDROM",
          "FileName": "env"
        }
      ]
    }
  }
}
JSON
