#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "DevicePathResolutionType": "virtio",
      "VirtioDevicePrefix": "google"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254",
          "UserDataPath": "/computeMetadata/v1/instance/attributes/user_data",
          "Headers": {
            "Metadata-Flavor": "Google"
          }
        }
      ],

      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON
