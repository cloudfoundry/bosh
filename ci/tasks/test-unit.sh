#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param RUBY_VERSION

echo "Starting $DB..."
case "$DB" in
  mysql)
    mv /var/lib/mysql /var/lib/mysql-src
    mkdir /var/lib/mysql
    mount -t tmpfs -o size=256M tmpfs /var/lib/mysql
    mv /var/lib/mysql-src/* /var/lib/mysql/

    sudo service mysql start
    ;;
  postgresql)
    mkdir /tmp/postgres
    mount -t tmpfs -o size=512M tmpfs /tmp/postgres
    mkdir /tmp/postgres/data
    chown postgres:postgres /tmp/postgres/data

    su postgres -c '
      export PATH=/usr/lib/postgresql/$DB_VERSION/bin:$PATH
      export PGDATA=/tmp/postgres/data
      export PGLOGS=/tmp/log/postgres
      mkdir -p $PGDATA
      mkdir -p $PGLOGS
      initdb -U postgres -D $PGDATA

      if ([ $DB_VERSION == "9.5" ] || [ $DB_VERSION == "9.6" ]); then
          echo "checkpoint_timeout=1h" >> $PGDATA/postgresql.conf
          echo "min_wal_size=300MB" >> $PGDATA/postgresql.conf
          echo "max_wal_size=300MB" >> $PGDATA/postgresql.conf
      fi

      pg_ctl start -w -l $PGLOGS/server.log -o "-N 400"
    '
    ;;
  sqlite)
    echo "Using sqlite"
    ;;
  *)
    echo "Usage: DB={mysql2|postgresql|sqlite} $0 {commands}"
    exit 1
esac

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

cd bosh-src/src
print_git_state

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH
export GOPATH=$(pwd)/go
bundle install --local
bundle exec rake --trace spec:unit

if [ "$DB" = "mysql" ]; then
  sudo service mysql stop
fi