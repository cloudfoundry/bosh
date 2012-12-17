#!/bin/sh
#
# setup warden

# linux version info
KERNEL_VERSION=2
MAJOR_KERNEL_REVISION=6
MINOR_KERNEL_REVISION=38

# default config file path
DEFAULT_CONFIG_DIRECTORY="config/linux.yml"

# linux kernel version after  method
kernel_version_after(){
  kernel_version=$(uname -r | cut -f 1 -d .)
  major_kernel_revision=$(uname -r | cut -f 2 -d .)
  minor_kernel_revision=$(uname -r | cut -f 3 -d .| cut -f 1 -d -)
  if [ $kernel_version -gt $KERNEL_VERSION ] || [ $kernel_version -eq $KERNEL_VERSION ] && [ $major_kernel_revision -gt $MAJOR_KERNEL_REVISION ] || [ $kernel_version -eq $KERNEL_VERSION ] && [ $major_kernel_revision -eq $MAJOR_KERNEL_REVISION ] && [ $minor_kernel_revision -ge $MINOR_KERNEL_REVISION ]
  then
    return 1
  else
    return 0
  fi
}

# get warden code directory here
if [ -z $1 ]
then
  echo "please define where to git clone your warden code"
  exit 0
else
  warden_dir=$1
fi

# get configure file directory here
[ -n $2 ] && config_file_dir=$DEFAULT_CONFIG_DIRECTORY || config_file_dir=$2

# check running linux kernel version and sure required kernel is installed, otherwise script will exit.
kernel_version_after
if [ $? -eq 0 ]
then
  echo "If you are running Ubuntu 10.04 (Lucid), make sure the backported Natty kernel is installed. After installing, reboot the system before continuing. install the kernel using the following command: sudo apt-get install -y linux-image-generic-lts-backport-natty"
  exit 0
fi

echo 'install required packages'
sudo apt-get --force-yes -y install libnl1 quota
sudo apt-get --force-yes -y install git-core

# mkdir if warden code directory not exist, and then git clone code
[ -d $warden_dir ] || mkdir $warden_dir

echo "git clone warden code"
cd $warden_dir
git clone https://github.com/cloudfoundry/warden.git

[ $? -ne 0 ] && exit 1

echo "bundle install"
cd "./warden/warden"
sudo env PATH=$PATH bundle install

echo "setup warden"
sudo env PATH=$PATH bundle exec rake setup[$config_file_dir]
