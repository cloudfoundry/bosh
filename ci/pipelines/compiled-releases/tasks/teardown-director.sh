#!/usr/bin/env bash

set -ex

mv director-state/* .
mv director-state/.bosh $HOME/

bosh-cli delete-env director.yml -l director-creds.yml
