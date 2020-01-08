#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh
check_param RUBY_VERSION

cleanup() {
  echo "Cleaning up"

  if [ "$DB" = "mysql" ]; then
    service mysql stop
  fi
}

trap cleanup EXIT

echo "Starting $DB..."
case "$DB" in
  mysql)
    mv /var/lib/mysql /var/lib/mysql-src
    mkdir /var/lib/mysql
    mount -t tmpfs -o size=512M tmpfs /var/lib/mysql
    mv /var/lib/mysql-src/* /var/lib/mysql/

    service mysql start
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
      mkdir -p $PGLOGS
      initdb -U postgres -D $PGDATA

      if [[ $DB_VERSION != "9.3" ]] && [[ $DB_VERSION != "9.4" ]]; then
        echo "checkpoint_timeout=1h" >> $PGDATA/postgresql.conf
        echo "min_wal_size=300MB" >> $PGDATA/postgresql.conf
        echo "max_wal_size=300MB" >> $PGDATA/postgresql.conf
      fi

      pg_lsclusters
      pg_ctlcluster $DB_VERSION main start
    '
    ;;
  sqlite)
    echo "Using sqlite"
    ;;
  *)
    echo "Usage: DB={mysql2|postgresql|sqlite} $0 {commands}"
    exit 1
esac

cd bosh-src/src
print_git_state

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH
export GOPATH=$(pwd)/go
gem install -f bundler
bundle update --bundler
bundle install --local
bundle exec rake --trace spec:unit
