#!/bin/bash

set -eu -o pipefail

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
  libffi-dev

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint | grep 'Key fingerprint = 5811 8E89 F3A9 1289 7C07  0ADB F762 2157 2C52 609D'
add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) main

apt-get update

apt-get install -y --no-install-recommends docker-engine

rm -rf /var/lib/apt/lists/*
