#!/bin/bash

set -xe
source /etc/profile.d/chruby.sh
chruby 2.3.1

apt-get install -y --no-install-recommends \
		apt-transport-https \
		ca-certificates \
		curl \
		software-properties-common && apt-get clean

curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -
apt-key fingerprint | grep 'Key fingerprint = 5811 8E89 F3A9 1289 7C07  0ADB F762 2157 2C52 609D'

sudo add-apt-repository \
		"deb https://apt.dockerproject.org/repo/ \
		ubuntu-$(lsb_release -cs) \
		main"

sudo apt-get update
sudo apt-get -y install docker-engine && apt-get clean
