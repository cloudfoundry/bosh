#!/usr/bin/env bash
set -eu -o pipefail

print_git_state() {
  if [ -d ".git" ] ; then
    echo "--> last commit..."
    TERM=xterm-256color git --no-pager log -1
    echo "---"
    echo "--> local changes (e.g., from 'fly execute')..."
    TERM=xterm-256color git --no-pager status --verbose
    echo "---"
  fi
}

print_ruby_info() {
   ruby -e 'puts "Using #{RUBY_DESCRIPTION.inspect}"'
}

run_as() {
  local user="${1}"
  shift

  echo "Running '${*}' as '${user}'"

  # shellcheck disable=SC2068
  sudo --preserve-env --set-home -u "${user}" ${@}
}

start_db() {
  local db_name=$1

  echo "Starting ${db_name}..."

  case "${db_name}" in
    mysql)
      export DB_HOST="127.0.0.1"
      export DB_PORT="3306"
      export DB_USER="root"
      export DB_PASSWORD="password"

      export MYSQL_ROOT=/var/lib/mysql
      if [ ! -d /var/lib/mysql-src ]; then # Set up MySQL if it's the first time
        mv "${MYSQL_ROOT}" /var/lib/mysql-src
        mkdir -p "${MYSQL_ROOT}"
        mount -t tmpfs -o size=512M tmpfs "${MYSQL_ROOT}"
        mv /var/lib/mysql-src/* "${MYSQL_ROOT}/"

        echo "Copy 'src/spec/assets/sandbox/database/database_server/{private_key,certificate.pem}' to '${MYSQL_ROOT}/'"
        cp bosh/src/spec/assets/sandbox/database/database_server/private_key "${MYSQL_ROOT}/server.key"
        cp bosh/src/spec/assets/sandbox/database/database_server/certificate.pem "${MYSQL_ROOT}/server.cert"

        {
          echo "[client]"
          echo "default-character-set=utf8"
          echo "[mysql]"
          echo "default-character-set=utf8"

          echo "[mysqld]"
          echo "collation-server = utf8_unicode_ci"
          echo "init-connect='SET NAMES utf8'"
          echo "character-set-server = utf8"
          echo 'sql-mode="STRICT_TRANS_TABLES"'
          echo "skip-log-bin"
          echo "max_connections = 1024"

          echo "ssl-cert=server.cert"
          echo "ssl-key=server.key"
          echo "require_secure_transport=ON"
          echo "max_allowed_packet=6M"
        } >> /etc/mysql/my.cnf
      fi

      service mysql start
      sleep 5
      mysql -h ${DB_HOST} \
            -P ${DB_PORT} \
            --user=${DB_USER} \
            --password=${DB_PASSWORD} \
            -e 'create database uaa;' > /dev/null 2>&1
      ;;

    postgresql)
      export DB_HOST="127.0.0.1"
      export DB_PORT="5432"
      export DB_USER="postgres"
      export DB_PASSWORD="smurf"
      export PGPASSWORD="${DB_PASSWORD}"

      export POSTGRES_ROOT="/tmp/postgres"
      if [ ! -d "${POSTGRES_ROOT}" ]; then # PostgreSQL hasn't been set up
        run_as postgres mkdir -p "${POSTGRES_ROOT}"

        export PGDATA="${POSTGRES_ROOT}/data"
        export PGLOGS="/tmp/log/postgres"
        export PGCLIENTENCODING="UTF8"

        run_as postgres mkdir -p "${PGDATA}" "${PGLOGS}"

        export POSTGRES_PASSWORD_FILE="${POSTGRES_ROOT}/bosh-postgres.password"
        echo "${DB_PASSWORD}" > "${POSTGRES_PASSWORD_FILE}"
        chown -R postgres:postgres "${PGDATA}"
        run_as postgres "$(which initdb)" -U postgres -D "${PGDATA}" --pwfile "${POSTGRES_PASSWORD_FILE}"

        # NOTE: certificates can only moved to ${PGDATA}/ _after_ `initdb` is run
        echo "Copy 'src/spec/assets/sandbox/database/database_server/{private_key,certificate.pem}' to '${PGDATA}'"
        cp bosh/src/spec/assets/sandbox/database/database_server/private_key "${PGDATA}/server.key"
        cp bosh/src/spec/assets/sandbox/database/database_server/certificate.pem "${PGDATA}/server.crt"
        chmod 600 ${PGDATA}/server.*

        export POSTGRES_CONF="${PGDATA}/postgresql.conf"
        export POSTGRES_PG_HBA="${PGDATA}/pg_hba.conf"

        {
          echo "max_connections = 1024"
          echo "shared_buffers = 240MB"
          echo "ssl = on"
          echo "client_encoding = 'UTF8'"
        } >> "${POSTGRES_CONF}"

        echo "hostssl all all 127.0.0.1/32 password" > "${POSTGRES_PG_HBA}"
        {
          echo "hostssl all all 0.0.0.0/32 password"
          echo "hostssl all all ::1/128 password"
          echo "hostssl all all localhost password"
        } >> "${POSTGRES_PG_HBA}"

        chown -R postgres:postgres "${PGDATA}" "${PGLOGS}"

        run_as postgres "$(which pg_ctl)" start --log="${PGLOGS}/server.log" --wait
        run_as postgres "$(which createdb)" -h "${DB_HOST}" uaa
      fi
      ;;

    sqlite)
      echo "Using sqlite"
      echo "      NOTE: this will not work for integration specs"
      ;;

    *)

      echo "Usage: DB={mysql|postgresql|sqlite} $0 {commands}"
      exit 1
  esac
}

if [ -d bosh-cli ] ; then
  install bosh-cli/*bosh-cli-*-linux-amd64 "/usr/local/bin/bosh"
fi

start_db "${DB}"

pushd bosh/src
  print_git_state
  print_ruby_info

  gem install -f bundler
  bundle install --local

  bundle exec rake --trace "${RAKE_TASK}"
popd
