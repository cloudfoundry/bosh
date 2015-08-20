#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

  base_dir=$(readlink -nf $(dirname $0)/../..)
  source $base_dir/lib/prelude_apply.bash
  source $base_dir/lib/prelude_bosh.bash

if [ "${stemcell_operating_system}" == "ubuntu" ]; then
  # Create list of installed packages
  run_in_bosh_chroot $chroot "dpkg -l > stemcell_dpkg_l.out"

  # Export list in stemcell tarball
  cp $chroot/$bosh_dir/stemcell_dpkg_l.out $work/stemcell/stemcell_dpkg_l.txt

elif [ "${stemcell_operating_system}" == "centos" ]; then
   # Create list of installed packages
  run_in_bosh_chroot $chroot "rpm -qa > stemcell_rpm_qa.out"

  # Export list in stemcell tarball
  cp $chroot/$bosh_dir/stemcell_rpm_qa.out $work/stemcell/stemcell_rpm_qa.txt

fi
