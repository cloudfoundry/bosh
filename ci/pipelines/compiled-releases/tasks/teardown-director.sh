#!/usr/bin/env bash

set -ex

ls -al director-state

cp -r director-state/* .
cp -r director-state/.bosh-init $HOME/
bosh-init delete bosh-init.yml
