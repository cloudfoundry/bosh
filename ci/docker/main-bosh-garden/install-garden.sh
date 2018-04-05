#!/bin/bash

set -xe

source /etc/profile.d/chruby.sh
chruby 2.3.1

mkdir -p /opt/garden/bin
cd /opt/garden

curl -o bin/gdn -L https://github.com/cloudfoundry/garden-runc-release/releases/download/v1.12.1/gdn-1.12.1
chmod +x bin/gdn

test "$(sha256sum bin/gdn)" == "ad82bc5b597ea356e738df2dc6b1f9e1ef619d6610fd5546512116bb98ce3921  bin/gdn"

curl -o bin/gaol -L https://github.com/contraband/gaol/releases/download/2016-8-22/gaol_linux
chmod +x bin/gaol

test "$(sha256sum bin/gaol)" == "754a69c2e5b6f5a366ab9cbacd52e366d9a062cff9cc4d46b6f52aebaaf59a96  bin/gaol"

