#!/bin/sh
rm /etc/resolv.conf
touch /etc/resolv.conf
rm /etc/ssh/ssh_host*key*
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
dpkg-reconfigure -fnoninteractive sysstat
