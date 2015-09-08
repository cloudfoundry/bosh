#!/usr/bin/env bash

check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

print_git_state() {
  if [ -d ".git" ] ; then
    echo "--> last commit..."
    TERM=xterm-256color git log -1
    echo "---"
    echo "--> local changes (e.g., from 'fly execute')..."
    TERM=xterm-256color git status --verbose
    echo "---"
  fi
}

start_db() {
  db=$1
  echo "Starting $db..."
  case "$db" in
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
}
