#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param RUBY_VERSION

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

cd bosh-src/src
print_git_state

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH
export GOPATH=$(pwd)/go
bundle install --local

bundle exec rake --trace spec:unit:migrations

if [ "$DB" = "mysql" ]; then
	#Restart rds mysql
	gem install aws-sdk --no-ri --no-rdoc
	gem install aws-sdk-core --no-ri --no-rdoc
	ruby ../ci/tasks/test-unit-remote-reboot-db.rb
fi