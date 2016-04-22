#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Explicit make the mount point for bind-mount
# Otherwise using none ubuntu host will fail creating vm
mkdir -p $chroot/warden-cpi-dev

# Run rsyslog and ssh using runit and replace /usr/sbin/service with a script which call runit
mkdir -p $chroot/etc/sv/ $chroot/etc/service/
cp -a $assets_dir/runit/rsyslog/ $chroot/etc/sv/rsyslog
cp -a $assets_dir/runit/ssh/ $chroot/etc/sv/ssh

run_in_chroot $chroot "
chmod +x /etc/sv/rsyslog/run
chmod +x /etc/sv/ssh/run
ln -s /etc/sv/rsyslog /etc/service/rsyslog
ln -s /etc/sv/ssh /etc/service/ssh
"

# Pending for disk_quota
#run_in_chroot $chroot "
#ln -s /proc/self/mounts /etc/mtab
#"

if grep -q -i ubuntu $chroot/etc/issue
# if this is Ubuntu stemcell
then
  # this version of unshare has the -p flag (trusty has an old version)
  # this is used to launch upstart as PID 1, in tests
  # upstart does not run in normal bosh-lite containers
  unshare_binary=$chroot/var/vcap/bosh/bin/unshare
  cp -f $assets_dir/unshare $unshare_binary
  chmod +x $unshare_binary
  chown root:root $unshare_binary

  # Replace /usr/sbin/service with a script which calls runit
  run_in_chroot $chroot "
  dpkg-divert --local --rename --add /usr/sbin/service
"
# Centos Stemcell
else
  # Add runsvdir-start for Centos to bootstrap agent
  cp -f $assets_dir/runsvdir-start $chroot/usr/sbin/runsvdir-start
  run_in_chroot $chroot "
  chmod +x /usr/sbin/runsvdir-start
  "
fi

cp -f $assets_dir/service $chroot/usr/sbin/service

run_in_chroot $chroot "
chmod +x /usr/sbin/service
"

# Configure go agent specifically for warden
cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "UseDefaultTmpDir": true,
      "UsePreformattedPersistentDisk": true,
      "BindMountPersistentDisk": true,
      "UseDirectoryAsEphemeralDisk": true
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "File",
          "SettingsPath": "/var/vcap/bosh/warden-cpi-agent-env.json"
        }
      ]
    }
  }
}
JSON
