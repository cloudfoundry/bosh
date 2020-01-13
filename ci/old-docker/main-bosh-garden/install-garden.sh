#!/bin/bash

set -xe

mkdir -p /opt/garden/bin
cd /opt/garden

curl -o bin/gdn -L https://github.com/cloudfoundry/garden-runc-release/releases/download/v1.16.4/gdn-1.16.4
chmod +x bin/gdn

test "$(sha256sum bin/gdn)" == "c4c37b9e9efd482876b9af82273f8dc4015302f5715da524e0d6b7eb7071a703  bin/gdn"

curl -o bin/gaol -L https://github.com/contraband/gaol/releases/download/2016-8-22/gaol_linux
chmod +x bin/gaol

test "$(sha256sum bin/gaol)" == "754a69c2e5b6f5a366ab9cbacd52e366d9a062cff9cc4d46b6f52aebaaf59a96  bin/gaol"

