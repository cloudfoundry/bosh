#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Infrastructure": {
    "DevicePathResolutionType": "virtio",
    "NetworkingType": "dhcp",

    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254"
        }
      ],
      "UseRegistry": true
    }
  }
}
JSON
