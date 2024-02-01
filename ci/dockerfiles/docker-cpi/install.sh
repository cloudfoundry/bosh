#!/bin/bash

set -eux -o pipefail

apt-get update

apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  dnsutils \
  git \
  iproute2 \
  openssh-client \
  software-properties-common \
  libpq-dev

# ruby-install dependencies
apt-get install -y \
  wget \
  build-essential \
  libyaml-dev \
  libgdbm-dev \
  libreadline-dev \
  libncurses5-dev \
  libffi-dev \
  bison
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

apt-get install -y --no-install-recommends docker-ce

# https://github.com/docker/cli/issues/4807
# As of 02/01/2024 a change in the "/etc/init.d/docker" script shipped with docker v25 
# is preventing the cpi image to work. 
# when start-bosh runs `service docker start` it errors with:
# "/etc/init.d/docker: 62: ulimit: error setting limit (Invalid argument)"
# disable resetting ulimit. Pre v25 the script contained `ulimit -n 1048576`
# the default in our base image is: 
# ulimit | grep file
# `open files                          (-n) 1048576`
# so it was a noOp..
# running `ulimit -Hn 1048576` will succeed.. The issue happens when we want to raise the ulimit.

sed -i 's/\(ulimit -Hn [0-9]*\)/#\1/' /etc/init.d/docker

rm -rf /var/lib/apt/lists/*
