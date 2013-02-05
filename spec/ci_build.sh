#!/bin/bash
set -e

source .rvmrc
gem list | grep bundler > /dev/null || gem install bundler
bundle check || bundle install --without development

bundle exec rake $@
