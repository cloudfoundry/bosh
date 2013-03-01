#!/bin/sh
rm /etc/resolv.conf
touch /etc/resolv.conf
rm /etc/ssh/ssh_host*key*

/etc/init.d/networking restart
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
dpkg-reconfigure -fnoninteractive sysstat
