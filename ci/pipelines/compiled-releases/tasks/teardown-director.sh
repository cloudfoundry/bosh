#!/usr/bin/env bash

cp -r director-state/* .
mv director-state/.bosh-init $HOME/
bosh-init delete bosh-init.yml
