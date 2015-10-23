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

set_up_vagrant_private_key() {
  if [ ! -f "$BOSH_VAGRANT_PRIVATE_KEY" ]; then
    key_path=$(mktemp -d /tmp/ssh_key.XXXXXXXXXX)/value
    echo "$BOSH_VAGRANT_PRIVATE_KEY" > $key_path
    chmod 600 $key_path
    export BOSH_VAGRANT_KEY_PATH=$key_path
  fi
}
