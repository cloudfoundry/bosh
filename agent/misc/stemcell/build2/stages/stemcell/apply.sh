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

manifest = {
    "name" => stemcell_name,
    "version" => version,
    "bosh_protocol" => bosh_protocol,
    "cloud_properties" => {}
}

File.open("stemcell.MF", "w") do |f|
  f.write(YAML.dump(manifest))
end
EOS

stemcell_tgz="$stemcell_name-$stemcell_infrastructure-$stemcell_version.tgz"
tar zvcf ../$stemcell_tgz *

echo "Generated stemcell: $work/$stemcell_tgz"
