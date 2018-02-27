#!/usr/bin/env bash

set -e

source bosh-src/ci/tasks/utils.sh

check_param RUBY_VERSION
check_param DB

echo "Starting $DB..."
case "$DB" in
  mysql)
    export DB_PASSWORD="password"
    mv /var/lib/mysql /var/lib/mysql-src
    mkdir /var/lib/mysql
    mount -t tmpfs -o size=512M tmpfs /var/lib/mysql
    mv /var/lib/mysql-src/* /var/lib/mysql/

    if [ "$DB_TLS" = true ]; then
      echo "....... DB TLS enabled ......."

      export MYSQLDIR=/var/lib/mysql
      cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/private_key $MYSQLDIR/server-key.pem
      cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/certificate.pem $MYSQLDIR/server-cert.pem
      echo '
[mysqld]
ssl-cert=server-cert.pem
ssl-key=server-key.pem
require_secure_transport=ON
max_allowed_packet=6M' >> /etc/mysql/my.cnf
    fi

    sudo service mysql start
    sleep 5
    ;;
  postgresql)
    export PATH=/usr/lib/postgresql/9.4/bin:$PATH
    export DB_PASSWORD="smurf"

    mkdir /tmp/postgres
    mount -t tmpfs -o size=512M tmpfs /tmp/postgres
    mkdir /tmp/postgres/data
    chown postgres:postgres /tmp/postgres/data
    export PGDATA=/tmp/postgres/data

    su postgres -c '
      export PATH=/usr/lib/postgresql/9.4/bin:$PATH
      export PGDATA=/tmp/postgres/data
      export PGLOGS=/tmp/log/postgres
      mkdir -p $PGDATA
      mkdir -p $PGLOGS
      echo $DB_PASSWORD > /tmp/bosh-postgres.password
      initdb -U postgres -D $PGDATA --pwfile /tmp/bosh-postgres.password
    '

    if [ "$DB_TLS" = true ]; then
      echo "....... DB TLS enabled ......."
      su postgres -c '
        export PGDATA=/tmp/postgres/data
        cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/private_key $PGDATA/server.key
        cp bosh-src/src/bosh-dev/assets/sandbox/database/database_server/certificate.pem $PGDATA/server.crt

        echo "ssl = on" >> $PGDATA/postgresql.conf
        echo "hostssl all all 127.0.0.1/32 password" > $PGDATA/pg_hba.conf

        chmod 600 $PGDATA/server.*
      '
    fi

    su postgres -c '
      export PATH=/usr/lib/postgresql/9.4/bin:$PATH
      export PGLOGS=/tmp/log/postgres
      pg_ctl start -l $PGLOGS/server.log -o "-N 400"
    '
    ;;
  *)
    echo "Usage: DB={mysql|postgresql} $0 {commands}"
    exit 1
esac

mv ./bosh-cli/*bosh-cli-*-linux-amd64 /usr/local/bin/bosh
chmod +x /usr/local/bin/bosh

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

agent_path=bosh-src/src/go/src/github.com/cloudfoundry/
mkdir -p $agent_path
cp -r bosh-agent $agent_path

cd bosh-src/src

set +x
print_git_state

bundle install --local

set +e
bundle exec rake --trace spec:integration_gocli

bundle_exit_code=$?

if [[ "$DB" = "mysql" && "$DB_TLS" = true ]]; then
  sudo service mysql stop
fi

exit $bundle_exit_code
