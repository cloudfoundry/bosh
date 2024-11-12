#!/usr/bin/env bash

rotate_bbl_certs() {
  for vars_store in $@; do
    local ops=""
    for cert in $(grep "ca: |" -B1 "${vars_store}" | grep -v "ca: |" | grep ':' | cut -d: -f1); do
        # shellcheck disable=SC2089
        ops="${ops}"'- {"type":"remove","path":"/'"${cert}"'"}\n'
    done
    bosh int "${vars_store}" -o <(echo -e $ops) > "${vars_store}.tmp"
    mv "${vars_store}.tmp" "${vars_store}"
    echo "Rotated certs in ${vars_store}"
  done
}

rotate_credhub_certs() {
  for ca in $(credhub find -n _ca | grep -e '_ca$' | cut -d' ' -f3); do
    credhub regenerate -n "${ca}"
    credhub bulk-regenerate --signed-by "${ca}"
  done
}

commit_bbl_state_dir() {
  local input_dir=${1?'Input git repository absolute path is required.'}
  local bbl_state_dir=${2?'BBL state relative path is required.'}
  local output_dir=${3?'Output git repository absolute path is required.'}
  local commit_message=${4:-'Update bbl state.'}

  pushd "${input_dir}/${bbl_state_dir}"
    if [[ -n $(git status --porcelain) ]]; then
      git config user.name "CI Bot"
      git config user.email "ci@localhost"
      git add --all .
      git commit -m "${commit_message}"
    fi
  popd

  shopt -s dotglob
  cp -R "${input_dir}/." "${output_dir}"
}

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

set_up_vagrant_private_key() {
  if [ ! -f "$BOSH_VAGRANT_PRIVATE_KEY" ]; then
    key_path=$(mktemp -d /tmp/ssh_key.XXXXXXXXXX)/value
    echo "$BOSH_VAGRANT_PRIVATE_KEY" > $key_path
    chmod 600 $key_path
    export BOSH_VAGRANT_KEY_PATH=$key_path
  fi
}

retry_command() {
  local retryable_command=$1
  set +e
  for i in {1..10}; do
    $retryable_command
    local status=$?
    if [ $status -ne 0 ]; then
      echo "attempt '${i}' exited with '${status}' sleeping 3s"
      sleep 3s
    else
      return 0
    fi
  done
  set -e
  echo "Timed out running command '${retryable_command}'"
  return 1
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
      export DB_USER="root"
      export DB_PASSWORD="password"
      export DB_PORT="3306"

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
      mysql -h 127.0.0.1 \
            -P ${DB_PORT} \
            --user=${DB_USER} \
            --password=${DB_PASSWORD} \
            -e 'create database uaa;' > /dev/null 2>&1
      ;;

    postgresql)
      export DB_USER="postgres"
      export DB_PASSWORD="smurf"
      export DB_PORT="5432"
      export PGPASSWORD="${DB_PASSWORD}"

      export POSTGRES_ROOT="/tmp/postgres"
      if [ ! -d "${POSTGRES_ROOT}" ]; then # PostgreSQL hasn't been set up
        mkdir -p "${POSTGRES_ROOT}"
        mount -t tmpfs -o size=512M tmpfs "${POSTGRES_ROOT}"

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
        run_as postgres "$(which createdb)" -h 127.0.0.1 uaa
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
