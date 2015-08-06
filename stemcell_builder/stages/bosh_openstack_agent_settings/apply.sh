#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

agent_settings_file=$chroot/var/vcap/bosh/agent.json

if [ "${stemcell_operating_system}" == "rhel" ]; then

  # CreatePartitionIfNoEphemeralDisk option is not supported on Rhel
  cat > $agent_settings_file <<JSON
{
  "Platform": {
    "Linux": {
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "ConfigDrive",
          "DiskPaths": [
            "/dev/disk/by-label/CONFIG-2",
            "/dev/disk/by-label/config-2"
          ],
          "MetaDataPath": "ec2/latest/meta-data.json",
          "UserDataPath": "ec2/latest/user-data"
        },
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254"
        }
      ],

      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON

else

  cat > $agent_settings_file <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "ConfigDrive",
          "DiskPaths": [
            "/dev/disk/by-label/CONFIG-2",
            "/dev/disk/by-label/config-2"
          ],
          "MetaDataPath": "ec2/latest/meta-data.json",
          "UserDataPath": "ec2/latest/user-data"
        },
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254"
        }
      ],

      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON

fi
