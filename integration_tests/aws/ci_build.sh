#!/bin/bash
set -e
set -x

source .rvmrc
gem list | grep bundler || gem install bundler
bundle check || bundle install



bundle exec bosh aws create vpc aws_configuration_template.yml.erb