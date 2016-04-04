#!/usr/bin/env bash

set -ex

mv director-state/* .
mv director-state/.bosh_init $HOME/

bosh-init delete bosh-init.yml
