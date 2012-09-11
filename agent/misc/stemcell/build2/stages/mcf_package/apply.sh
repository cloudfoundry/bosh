#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source ${base_dir}/lib/prelude_apply.bash

micro_src=${HOME}/micro
now=`date +%Y%m%d-%H%M%S`
dest_dir=mcf/$now
archive_dir_name=micro
archive_dir=${dest_dir}/${archive_dir_name}
mkdir --parents ${archive_dir}

if [ -z "${MCF_VERSION:-}" ]; then
    MCF_VERSION="dev build $now"
    echo 'To build a release version, set the MCF_VERSION environment variable.'
fi

${image_vsphere_ovf_ovftool_path} \
    --extraConfig:displayname="Micro Cloud Foundry v${MCF_VERSION}" \
    ${work}/vsphere/image.ovf \
    ${archive_dir}/micro

cp ${micro_src}/micro/README ${archive_dir}
cp ${micro_src}/micro/RELEASE_NOTES ${archive_dir}

cd ${dest_dir}
zip --recurse-paths micro.zip ${archive_dir_name}
