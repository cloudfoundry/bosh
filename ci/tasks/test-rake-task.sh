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

  sudo --preserve-env --set-home -u "${user}" "${@}"
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
          echo "innodb_flush_log_at_trx_commit = 2"
          echo "innodb_doublewrite = 0"

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
      export PGDATA="${POSTGRES_ROOT}/data"
      export PGLOGS="/tmp/log/postgres"
      export PGWAL="/tmp/postgres_wal"
      export PGCLIENTENCODING="UTF8"

      # Ensure ${POSTGRES_ROOT} is its own 512M tmpfs mount before any other
      # work, including the PG_VERSION check.  All three conditions must hold:
      # (1) a mountpoint here (not merely under a parent tmpfs — findmnt reports
      # the parent when POSTGRES_ROOT is not separately mounted, which would
      # falsely pass the type/size checks), (2) type is tmpfs, (3) size is 512M.
      # SIZE is compared as bytes (--bytes) rather than a human-formatted string
      # such as "512M" because findmnt output format varies across util-linux
      # versions and locales (e.g., "512M" vs "512.0M").
      mkdir -p "${POSTGRES_ROOT}"
      local _fstype _fssize
      _fstype=$(findmnt --noheadings --raw -o FSTYPE "${POSTGRES_ROOT}" 2>/dev/null || echo "none")
      _fssize=$(findmnt --noheadings --raw --bytes -o SIZE "${POSTGRES_ROOT}" 2>/dev/null || echo "0")
      if ! mountpoint -q "${POSTGRES_ROOT}" || \
         [ "${_fstype}" != "tmpfs" ] || \
         [ "${_fssize}" -ne 536870912 ]; then
        # Stop any running PostgreSQL server before (re-)mounting to avoid EBUSY.
        if run_as postgres "$(which pg_ctl)" status > /dev/null 2>&1; then
          run_as postgres "$(which pg_ctl)" stop -m fast
        fi
        if mountpoint -q "${POSTGRES_ROOT}"; then
          umount "${POSTGRES_ROOT}"
        fi
        mount -t tmpfs -o size=512M tmpfs "${POSTGRES_ROOT}"
      fi
      chown postgres:postgres "${POSTGRES_ROOT}"

      if [ ! -f "${PGDATA}/PG_VERSION" ]; then # PostgreSQL hasn't been initialized
        rm -rf "${PGWAL}"
        mkdir -p "${PGWAL}"
        chown postgres:postgres "${PGWAL}"
        run_as postgres mkdir -p "${PGDATA}" "${PGLOGS}"

        POSTGRES_PASSWORD_FILE="${POSTGRES_ROOT}/bosh-postgres.password"
        echo "${DB_PASSWORD}" > "${POSTGRES_PASSWORD_FILE}"
        chown postgres:postgres "${POSTGRES_PASSWORD_FILE}"
        chown -R postgres:postgres "${PGDATA}"
        run_as postgres "$(which initdb)" -U postgres -D "${PGDATA}" -X "${PGWAL}" --pwfile "${POSTGRES_PASSWORD_FILE}"

        # NOTE: certificates can only moved to ${PGDATA}/ _after_ `initdb` is run
        echo "Copy 'src/spec/assets/sandbox/database/database_server/{private_key,certificate.pem}' to '${PGDATA}'"
        cp bosh/src/spec/assets/sandbox/database/database_server/private_key "${PGDATA}/server.key"
        cp bosh/src/spec/assets/sandbox/database/database_server/certificate.pem "${PGDATA}/server.crt"
        chmod 600 ${PGDATA}/server.*

        POSTGRES_CONF="${PGDATA}/postgresql.conf"
        POSTGRES_PG_HBA="${PGDATA}/pg_hba.conf"

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

        chown -R postgres:postgres "${PGDATA}" "${PGLOGS}" "${PGWAL}"
      fi

      # Ensure the log directory exists; it is created during init but may be
      # absent if the container was partially reset.
      run_as postgres mkdir -p "${PGLOGS}"

      run_as postgres "$(which pg_ctl)" status > /dev/null 2>&1 || \
        run_as postgres "$(which pg_ctl)" start --log="${PGLOGS}/server.log" --wait

      # Wait for the server to accept connections, retrying for up to 30s.
      # Raw sudo (not run_as) avoids printing "Running ..." on every retry.
      local _pg_tries=0
      until sudo --preserve-env --set-home -u postgres \
            "$(which pg_isready)" -h "${DB_HOST}" -p "${DB_PORT}" -q; do
        _pg_tries=$((_pg_tries + 1))
        if [ "${_pg_tries}" -ge 30 ]; then
          echo "ERROR: PostgreSQL at ${DB_HOST}:${DB_PORT} did not become ready after ${_pg_tries}s" >&2
          exit 1
        fi
        sleep 1
      done

      # Apply performance settings via ALTER SYSTEM (idempotent: writes to
      # postgresql.auto.conf, never grows postgresql.conf) so they are active
      # for both fresh and reused clusters.  Each statement is a separate -c call
      # because psql's simple query protocol wraps compound queries in a single
      # implicit transaction, and ALTER SYSTEM cannot run inside a transaction.
      run_as postgres "$(which psql)" -h "${DB_HOST}" -p "${DB_PORT}" -U postgres \
        -c "ALTER SYSTEM SET fsync = off"
      run_as postgres "$(which psql)" -h "${DB_HOST}" -p "${DB_PORT}" -U postgres \
        -c "ALTER SYSTEM SET synchronous_commit = off"
      run_as postgres "$(which psql)" -h "${DB_HOST}" -p "${DB_PORT}" -U postgres \
        -c "ALTER SYSTEM SET full_page_writes = off"
      run_as postgres "$(which psql)" -h "${DB_HOST}" -p "${DB_PORT}" -U postgres \
        -c "SELECT pg_reload_conf()"

      # createdb has no --if-not-exists flag; check pg_database instead.
      # Command substitution (not a pipe) is used so any psql connection failure
      # propagates as a script error rather than being silently treated as
      # "database does not exist".  Raw sudo (not run_as) avoids run_as's
      # stdout echo polluting the captured output.
      local _uaa_exists
      _uaa_exists=$(sudo --preserve-env --set-home -u postgres \
        psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname = 'uaa'")
      if [ "${_uaa_exists}" != "1" ]; then
        run_as postgres "$(which createdb)" -h "${DB_HOST}" -p "${DB_PORT}" uaa
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

if [ -d release-details/.git ]; then
  export PARALLEL_RUNTIME_LOG="$(pwd)/release-details/parallel_spec_runtimes/integration_${DB}_${UPDATE_VM_STRATEGY:-delete-create}.log"
fi

start_db "${DB}"

pushd bosh/src
  print_git_state
  print_ruby_info

  gem install -f bundler
  bundle install --local

  bundle exec rake --trace "${RAKE_TASK}"
popd

if [ -d "release-details/.git" ] && [ -n "${PARALLEL_RUNTIME_LOG:-}" ] && [ -s "${PARALLEL_RUNTIME_LOG}" ]; then
  git -C release-details config user.name "CF-Bosh CI-Bot"
  git -C release-details config user.email "cf-bosh-ci-bot@localhost"
  git -C release-details add "parallel_spec_runtimes/integration_${DB}_${UPDATE_VM_STRATEGY:-delete-create}.log"
  git -C release-details diff --staged --quiet || git -C release-details commit -m "Update parallel_runtime_rspec log for ${DB} ${UPDATE_VM_STRATEGY:-delete-create}"
fi
