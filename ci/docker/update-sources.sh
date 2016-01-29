#!/usr/bin/env bash

tee -a /etc/apt/sources.list <<EOF
deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty main
deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty main
deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty-updates main
deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty-updates main
deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty universe
deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty universe
deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty-updates universe
deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ trusty-updates universe
deb http://security.ubuntu.com/ubuntu trusty-security main
deb-src http://security.ubuntu.com/ubuntu trusty-security main
deb http://security.ubuntu.com/ubuntu trusty-security universe
deb-src http://security.ubuntu.com/ubuntu trusty-security universe
EOF
