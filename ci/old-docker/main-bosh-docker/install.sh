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
  bison \
  build-essential \
  libyaml-dev \
  libgdbm-dev \
  libreadline-dev \
  libncurses5-dev \
  libffi-dev \
  zlib1g-dev

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint | grep '9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88'
add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

apt-get update

apt-get install -y --no-install-recommends docker-ce

rm -rf /var/lib/apt/lists/*
