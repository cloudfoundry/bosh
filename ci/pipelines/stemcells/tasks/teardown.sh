#!/usr/bin/env bash

set -ex

mv director-state/* .
mv director-state/.bosh $HOME/
mv bosh-cli/bosh-cli-* /usr/local/bin/bosh-cli

bosh-cli delete-env director.yml -l director-creds.yml
