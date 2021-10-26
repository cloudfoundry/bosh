#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

if [ -d integration-tests-parallel-runtime ]; then
  cp integration-tests-parallel-runtime/parallel_runtime_rspec.log bosh-src/src/parallel_runtime_rspec.log
fi

check_param RUBY_VERSION
check_param DB

echo "Starting $DB..."
case "$DB" in
  mysql)
    export DB_PASSWORD="password"
    if [ ! -d /var/lib/mysql-src ]; then # Set up MySQL if it's the first time
      mv /var/lib/mysql /var/lib/mysql-src
      mkdir -p /var/lib/mysql
      mount -t tmpfs -o size=512M tmpfs /var/lib/mysql
      mv /var/lib/mysql-src/* /var/lib/mysql/
    fi
    echo '
[client]
default-character-set=utf8

[mysql]
default-character-set=utf8

[mysqld]
collation-server = utf8_unicode_ci
init-connect='SET NAMES utf8'
character-set-server = utf8
sql-mode="STRICT_TRANS_TABLES"
max_connections = 1024' >> /etc/mysql/my.cnf

    if [ "$DB_TLS" = true ]; then
      echo "....... DB TLS enabled ......."

      export MYSQLDIR=/var/lib/mysql
      cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/private_key $MYSQLDIR/server-key.pem
      cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/certificate.pem $MYSQLDIR/server-cert.pem
      echo '
ssl-cert=server-cert.pem
ssl-key=server-key.pem
require_secure_transport=ON
max_allowed_packet=6M' >> /etc/mysql/my.cnf
    fi

    service mysql start
    sleep 5
    ;;
  postgresql)
    export PATH=$( echo /usr/lib/postgresql/*/bin ):$PATH
    export DB_PASSWORD="smurf"

    if [ ! -d /tmp/postgres ]; then # PostgreSQL hasn't been set up
      mkdir /tmp/postgres
      mount -t tmpfs -o size=512M tmpfs /tmp/postgres
      mkdir /tmp/postgres/data
      chown postgres:postgres /tmp/postgres/data
      export PGDATA=/tmp/postgres/data

      su postgres -c '
        export PATH=$( echo /usr/lib/postgresql/*/bin ):$PATH
        export PGDATA=/tmp/postgres/data
        export PGLOGS=/tmp/log/postgres
        mkdir -p $PGDATA
        mkdir -p $PGLOGS
        echo $DB_PASSWORD > /tmp/bosh-postgres.password
        initdb -U postgres -D $PGDATA --pwfile /tmp/bosh-postgres.password
      '

      echo "max_connections = 1024" >> $PGDATA/postgresql.conf
      echo "shared_buffers = 240MB" >> $PGDATA/postgresql.conf

      if [ "$DB_TLS" = true ]; then
        echo "....... DB TLS enabled ......."
        cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/private_key $PGDATA/server.key
        cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/certificate.pem $PGDATA/server.crt
        chown postgres $PGDATA/server.key
        chown postgres $PGDATA/server.crt
        su postgres -c '
          export PGDATA=/tmp/postgres/data
          echo "ssl = on" >> $PGDATA/postgresql.conf
          echo "client_encoding = 'UTF8'" >> $PGDATA/postgresql.conf
          echo "hostssl all all 127.0.0.1/32 password" > $PGDATA/pg_hba.conf
          echo "hostssl all all 0.0.0.0/32 password" >> $PGDATA/pg_hba.conf
          echo "hostssl all all ::1/128 password" >> $PGDATA/pg_hba.conf
          echo "hostssl all all localhost password" >> $PGDATA/pg_hba.conf

          chmod 600 $PGDATA/server.*
        '
      fi

      su postgres -c '
        export PATH=$( echo /usr/lib/postgresql/*/bin ):$PATH
        export PGLOGS=/tmp/log/postgres
        export PGCLIENTENCODING=UTF8
        pg_ctl start -l $PGLOGS/server.log -o "-N 400"
      '
    fi
    ;;
  *)
    echo "Usage: DB={mysql|postgresql} $0 {commands}"
    exit 1
esac

cp ./bosh-cli/*bosh-cli-*-linux-amd64 /usr/local/bin/bosh
chmod +x /usr/local/bin/bosh

agent_path=bosh-src/src/go/src/github.com/cloudfoundry/
mkdir -p $agent_path
cp -r bosh-agent $agent_path

pushd bosh-src/src
  print_git_state

  gem install -f bundler
  bundle update --bundler
  bundle install --local

  set +e
  bundle exec rake --trace spec:integration

  bundle_exit_code=$?

  if [[ "$DB" = "mysql" && "$DB_TLS" = true ]]; then
    service mysql stop
  fi
popd

mkdir -p parallel-runtime-log
cp bosh-src/src/parallel_runtime_rspec.log parallel-runtime-log/parallel_runtime_rspec.log

exit $bundle_exit_code
