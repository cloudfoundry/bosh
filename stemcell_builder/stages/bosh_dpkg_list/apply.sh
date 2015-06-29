#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ "${stemcell_operating_system}" == "ubuntu" ]; then
  base_dir=$(readlink -nf $(dirname $0)/../..)
  source $base_dir/lib/prelude_apply.bash
  source $base_dir/lib/prelude_bosh.bash

  # Create list of installed packages
  run_in_bosh_chroot $chroot "dpkg -l > stemcell_dpkg_l.out"

  # Export list in stemcell tarball
  cp $chroot/$bosh_dir/stemcell_dpkg_l.out $work/stemcell/stemcell_dpkg_l.txt
fi
