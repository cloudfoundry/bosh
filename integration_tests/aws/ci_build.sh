#!/bin/bash
set -e
set -x

gem list | grep bundler || gem install bundler
bundle check || bundle install



bundle exec bosh aws create vpc aws_configuration_template.yml.erb