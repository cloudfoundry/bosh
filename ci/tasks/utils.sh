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
    TERM=xterm-256color git --no-pager log -1
    echo "---"
    echo "--> local changes (e.g., from 'fly execute')..."
    TERM=xterm-256color git --no-pager status --verbose
    echo "---"
  fi
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
      echo "sleeping 3s"
      sleep 3s
    else
      return 0
    fi
  done
  set -e
  echo "Timed out running command '$retryable_command'"
  return 1
}
