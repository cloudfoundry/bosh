#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

check_param RUBY_VERSION
check_param DB

echo "Starting $DB..."
case "$DB" in
  mysql)
    sudo service mysql start
    ;;
  postgresql)
    su postgres -c '
      export PATH=/usr/lib/postgresql/9.4/bin:$PATH
      export PGDATA=/tmp/postgres
      export PGLOGS=/tmp/log/postgres
      mkdir -p $PGDATA
      mkdir -p $PGLOGS
      initdb -U postgres -D $PGDATA
      pg_ctl start -l $PGLOGS/server.log -o "-N 400"
    '
    ;;
  *)
    echo $"Usage: DB={mysql|postgresql} $0 {commands}"
    exit 1
esac

cd bosh-src

# NOTE: We start the sandbox with the Ruby version specified in the BOSH
# release. The integration runner switches the CLI based upon the RUBY_VERSION
# environment variable.
BOSH_RUBY=$(
  grep -E "ruby-.*.tar.gz" release/packages/ruby/spec |\
  sed -r "s/^.*ruby-(.*).tar.gz/\1/"
)
source /etc/profile.d/chruby.sh
chruby $BOSH_RUBY

print_git_state

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true
bundle install --local
bundle exec rake --trace go spec:integration
