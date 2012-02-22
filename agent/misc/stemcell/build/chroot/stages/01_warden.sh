#!/bin/bash

set -e

if [ $# -lt 1 ]
then
  echo "Usage: `basename $0` [chroot_target]"
  exit 1
fi

if [ `id -u` -ne "0" ]
then
  echo "Sorry, you need to be root"
  exit 1
fi

target=$1

tmpfile=`mktemp`

echo "Creating base stemcell archive at $tmpfile"
tar -C $target -czf $tmpfile .

echo "Storing stemcell archive in chroot at ${target}/var/vcap/stemcell_base.tar.gz"
mkdir -p $target/var/vcap
mv $tmpfile $target/var/vcap/stemcell_base.tar.gz
chmod 0700 $target/var/vcap/stemcell_base.tar.gz