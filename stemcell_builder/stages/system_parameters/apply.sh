#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# set the infrastructure for the agent to "vsphere" when building the vcloud stemcell
if [ "${stemcell_infrastructure}" == "vcloud" ]; then
  stemcell_infrastructure=vsphere
fi

echo -n $stemcell_infrastructure > $chroot/var/vcap/bosh/etc/infrastructure

# Temporary workaround: if we are building a RHEL and PhotonOS stemcell, tell the BOSH agent
# it's a CentOS machine. This is required because the current version of bosh-agent
# does not recognize the OS type "rhel" and "photonos".
#
# This workaround should be reverted once we can go back to the latest version of
# the bosh-agent submodule. See
os="${stemcell_operating_system}"
if [ "${os}" == "rhel" ] || [ "${os}" == "photonos" ] ; then
  os="centos"
fi

echo -n ${os} > $chroot/var/vcap/bosh/etc/operating_system

echo -n ${stemcell_version} > $chroot/var/vcap/bosh/etc/stemcell_version

pushd /bosh
has_uncommitted_changes=""
if ! git diff --quiet --exit-code; then
  has_uncommitted_changes="+"
fi

echo -n $(git rev-parse HEAD)${has_uncommitted_changes} > $chroot/var/vcap/bosh/etc/stemcell_git_sha1
popd
