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
