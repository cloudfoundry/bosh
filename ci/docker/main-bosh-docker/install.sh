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
  ruby \
  software-properties-common

curl -o /tmp/download https://storage.googleapis.com/golang/go1.9.5.linux-amd64.tar.gz
echo "d21bdabf4272c2248c41b45cec606844bdc5c7c04240899bde36c01a28c51ee7 /tmp/download" | sha256sum -c
mkdir /usr/local/go
tar -xzf /tmp/download -C /usr/local/go --strip-components=1
rm /tmp/download

curl -fsSL https://apt.dockerproject.org/gpg | apt-key add -
apt-key fingerprint | grep 'Key fingerprint = 5811 8E89 F3A9 1289 7C07  0ADB F762 2157 2C52 609D'
add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"

apt-get update

apt-get install -y --no-install-recommends docker-engine

rm -rf /var/lib/apt/lists/*
