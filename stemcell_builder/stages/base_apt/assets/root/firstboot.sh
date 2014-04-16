#!/bin/sh

# ubuntu trusty+ needs /etc/resolv.conf to be a symlink, so delete contents
# instead of removing the file to preserve the link
cat /dev/null > /etc/resolv.conf
rm /etc/ssh/ssh_host*key*

/etc/init.d/networking restart
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
dpkg-reconfigure -fnoninteractive sysstat
