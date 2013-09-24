#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

pushd $work/stemcell

# compute checksum of the image file
stemcell_checksum=`shasum -a 1 image | cut -f1 -d' '`

$ruby_bin <<EOS
require "yaml"

stemcell_name = "$stemcell_name"
stemcell_tgz = "$stemcell_tgz"
version = "$stemcell_version"
bosh_protocol = "$bosh_protocol_version".to_i
stemcell_checksum = "$stemcell_checksum"
stemcell_infrastructure = "$stemcell_infrastructure"
hypervisor = "${stemcell_hypervisor:-kvm}"

case hypervisor
when "kvm"
  container_format = "bare"
  disk_format = "qcow2"
when "xen"
  container_format = "bare"
  disk_format = "raw"
end

manifest = {
    "name" => stemcell_name,
    "version" => version,
    "bosh_protocol" => bosh_protocol,
    "sha1" => stemcell_checksum,
    "cloud_properties" => {
        "name" => stemcell_name,
        "version" => version,
        "infrastructure" => stemcell_infrastructure,
        "disk_format" => disk_format,
        "container_format" => container_format,
        "os_type" => "linux",
        "os_distro" => "ubuntu",
        "architecture" => "x86_64",
        "auto_disk_config" => "true"
    }
}

File.open("stemcell.MF", "w") do |f|
  f.write(Psych.dump(manifest))
end
EOS

tar zvcf ../$stemcell_tgz *

echo "Generated stemcell: $work/$stemcell_tgz"
