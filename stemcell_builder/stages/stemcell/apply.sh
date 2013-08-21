#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

pushd $work/stemcell

# compute checksum of the image file
stemcell_checksum=`shasum -a 1 image | cut -f1 -d' '`

# NOTE: architecture and root_device_name aren't dynamically detected
# as we don't have a way to persist values across stages, and until we
# build for multiple architectures or multiple root devices, hardcoding
# the values is fine.
# The values are only used in AWS, but still applies to vSphere
$ruby_bin <<EOS
require "yaml"

stemcell_name = "$stemcell_name"
stemcell_tgz = "$stemcell_tgz"
version = "$stemcell_version"
bosh_protocol = "$bosh_protocol_version".to_i
stemcell_infrastructure = "$stemcell_infrastructure"
stemcell_checksum = "$stemcell_checksum"

manifest = {
    "name" => stemcell_name,
    "version" => version,
    "bosh_protocol" => bosh_protocol,
    "sha1" => stemcell_checksum,
    "cloud_properties" => {
        "name" => stemcell_name,
        "version" => version,
        "infrastructure" => stemcell_infrastructure,
        "architecture" => "x86_64",
        "root_device_name" => "/dev/sda1"
    }
}

File.open("stemcell.MF", "w") do |f|
  f.write(Psych.dump(manifest))
end
EOS

tar zvcf ../$stemcell_tgz *

echo "Generated stemcell: $work/$stemcell_tgz"
