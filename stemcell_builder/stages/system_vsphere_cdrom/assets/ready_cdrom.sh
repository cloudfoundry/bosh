if [ -f /dev/bosh-cdrom ]
then
  rm -f /dev/bosh-cdrom
else
  touch /dev/bosh-cdrom
fi