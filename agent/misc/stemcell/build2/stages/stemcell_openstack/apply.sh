#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

kernel_image_name=kernel.img
ramdisk_image_name=initrd.img

pushd $work

if [ ! -e "${kernel_image_name:-}" ]
then
  kernel_image_name=
fi

if [ ! -e "${ramdisk_image_name:-}" ]
then
  ramdisk_image_name=
fi

popd

pushd $work/stemcell

$ruby_bin <<EOS
require "yaml"

stemcell_name = "$stemcell_name"
version = "$stemcell_version"
bosh_protocol = "$bosh_protocol_version".to_i
stemcell_infrastructure = "$stemcell_infrastructure"
kernel_file = "$kernel_image_name"
ramdisk_file = "$ramdisk_image_name"

manifest = {
    "name" => stemcell_name,
    "version" => version,
    "bosh_protocol" => bosh_protocol,
    "cloud_properties" => {
        "infrastructure" => stemcell_infrastructure,
        "disk_format" => "ami",
        "container_format" => "ami"
    }
}

unless (kernel_file.nil? || kernel_file.empty?)
    manifest["cloud_properties"]["kernel_file"] = kernel_file
end

unless (ramdisk_file.nil? || ramdisk_file.empty?)
    manifest["cloud_properties"]["ramdisk_file"] = ramdisk_file
end

File.open("stemcell.MF", "w") do |f|
  f.write(YAML.dump(manifest))
end
EOS

stemcell_tgz="$stemcell_name-$stemcell_infrastructure-$stemcell_version.tgz"
tar zvcf ../$stemcell_tgz *

echo "Generated stemcell: $work/$stemcell_tgz"