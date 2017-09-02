#!/bin/bash

set -xe

source /etc/profile.d/chruby.sh
chruby 2.3.1

mkdir -p /opt/garden/bin
cd /opt/garden

curl -o bin/gdn -L https://github.com/cloudfoundry/garden-runc-release/releases/download/v1.9.0/gdn-1.9.0
chmod +x bin/gdn

test "$(sha256sum bin/gdn)" == "a19e5db692f0223b29639f2a609c67461d3a5795adc91df8985e42ebd55349a7  bin/gdn"

curl -o bin/gaol -L https://github.com/contraband/gaol/releases/download/2016-8-22/gaol_linux
chmod +x bin/gaol

test "$(sha256sum bin/gaol)" == "754a69c2e5b6f5a366ab9cbacd52e366d9a062cff9cc4d46b6f52aebaaf59a96  bin/gaol"

