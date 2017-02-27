#!/bin/bash

source /etc/profile.d/chruby.sh
chruby 2.3.1

apt-get install -y --no-install-recommends \
		apt-transport-https \
		ca-certificates \
		curl \
		software-properties-common

curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -

apt-key fingerprint 58118E89F3A912897C070ADBF76221572C52609D
#TODO: verify output

sudo add-apt-repository \
		"deb https://apt.dockerproject.org/repo/ \
		ubuntu-$(lsb_release -cs) \
		main"

sudo apt-get update
sudo apt-get -y install docker-engine
