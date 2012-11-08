#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

pushd $work/stemcell

$ruby_bin <<EOS
require "yaml"

stemcell_name = "$stemcell_name"
version = "$stemcell_version"
bosh_protocol = "$bosh_protocol_version".to_i
stemcell_infrastructure = "$stemcell_infrastructure"
hypervisor = "${stemcell_hypervisor:-kvm}"

case hypervisor
when "kvm"
  disk_format = "qcow2"
when "xen"
  disk_format = "ami"
end

manifest = {
    "name" => stemcell_name,
    "version" => version,
    "bosh_protocol" => bosh_protocol,
    "cloud_properties" => {
        "name" => stemcell_name,
        "version" => version,
        "infrastructure" => stemcell_infrastructure,
        "disk_format" => disk_format,
        "container_format" => "bare"
    }
}

File.open("stemcell.MF", "w") do |f|
  f.write(YAML.dump(manifest))
end
EOS

stemcell_tgz="$stemcell_name-$stemcell_infrastructure-\
${stemcell_hypervisor:-kvm}-$stemcell_version.tgz"

tar zvcf ../$stemcell_tgz *

echo "Generated stemcell: $work/$stemcell_tgz"