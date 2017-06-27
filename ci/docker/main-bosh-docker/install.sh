#!/bin/bash

set -eu -o pipefail

apt-get update

apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  git \
  iproute2 \
  openssh-client \
  ruby \
  software-properties-common

curl -o /tmp/download https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz
echo "1862f4c3d3907e59b04a757cfda0ea7aa9ef39274af99a784f5be843c80c6772 /tmp/download" | sha256sum -c

tar -xzf /tmp/download -C /usr/local --strip-components=1
rm /tmp/download

curl -fsSL https://apt.dockerproject.org/gpg | apt-key add -
apt-key fingerprint | grep 'Key fingerprint = 5811 8E89 F3A9 1289 7C07  0ADB F762 2157 2C52 609D'
add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"

apt-get update

apt-get install -y --no-install-recommends docker-engine

rm -rf /var/lib/apt/lists/*
