#!/bin/sh

# ubuntu trusty+ needs /etc/resolv.conf to be a symlink, so delete contents
# instead of removing the file to preserve the link
> /etc/resolv.conf
rm /etc/ssh/ssh_host*key*

ifdown -a --exclude=lo
ifup -a --exclude=lo

dpkg-reconfigure -fnoninteractive -pcritical openssh-server
dpkg-reconfigure -fnoninteractive sysstat
