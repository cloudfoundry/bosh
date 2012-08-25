#!/bin/bash
#
# script to setup gems
#
set -e

gem update --system
# temporary workaround
gem install excon -v 0.14.0
gem install bosh_deployer
rbenv rehash
