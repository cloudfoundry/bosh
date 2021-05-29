#!/bin/bash

set -xe

mkdir -p /opt/garden/bin
cd /opt/garden

curl -o bin/gdn -L https://github.com/cloudfoundry/garden-runc-release/releases/download/v1.19.28/gdn-1.19.28
chmod +x bin/gdn

test "$(sha256sum bin/gdn)" == "988f072acdf764eeb418ea7635ef9619e24f27eac1c635887df9ff69fad91923  bin/gdn"

curl -o bin/gaol -L https://github.com/contraband/gaol/releases/download/2016-8-22/gaol_linux
chmod +x bin/gaol

test "$(sha256sum bin/gaol)" == "754a69c2e5b6f5a366ab9cbacd52e366d9a062cff9cc4d46b6f52aebaaf59a96  bin/gaol"

