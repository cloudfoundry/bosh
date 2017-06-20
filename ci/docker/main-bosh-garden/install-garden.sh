#!/bin/bash

set -xe

source /etc/profile.d/chruby.sh
chruby 2.3.1

mkdir -p /opt/garden/bin
cd /opt/garden

curl -o bin/gdn -L https://github.com/cloudfoundry/garden-runc-release/releases/download/v1.8.0/gdn-1.8.0
chmod +x bin/gdn

test "$(sha256sum bin/gdn)" == "0efad193517aa2d97e167f2ca1ca349888bdf55a4837b21b76e2aefd23b82723  bin/gdn"

curl -o bin/gaol -L https://github.com/contraband/gaol/releases/download/2016-8-22/gaol_linux
chmod +x bin/gaol

test "$(sha256sum bin/gaol)" == "754a69c2e5b6f5a366ab9cbacd52e366d9a062cff9cc4d46b6f52aebaaf59a96  bin/gaol"

