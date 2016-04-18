#!/usr/bin/env bash

get_stack_info() {
  local stack_name=$1

  echo "$(aws cloudformation describe-stacks)" | \
  jq --arg stack_name ${stack_name} '.Stacks[] | select(.StackName=="\($stack_name)")'
}

get_stack_info_of() {
  local stack_info=$1
  local key=$2
  echo "${stack_info}" | jq -r --arg key ${key} '.Outputs[] | select(.OutputKey=="\($key)").OutputValue'
}

get_stack_status() {
  local stack_name=$1

  local stack_info=$(get_stack_info $stack_name)
  echo "${stack_info}" | jq -r '.StackStatus'
}

check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

print_git_state() {
  echo "--> last commit..."
  TERM=xterm-256color git log -1
  echo "---"
  echo "--> local changes (e.g., from 'fly execute')..."
  TERM=xterm-256color git status --verbose
  echo "---"
}

check_for_rogue_vm() {
  local ip=$1
  set +e
  nc -vz -w10 $ip 22
  status=$?
  set -e
  if [ "${status}" == "0" ]; then
    echo "aborting due to vm existing at ${ip}"
    exit 1
  fi
}

declare -a on_exit_items
on_exit_items=()

function on_exit {
  echo "Running ${#on_exit_items[@]} on_exit items..."
  for i in "${on_exit_items[@]}"
  do
    for try in $(seq 0 9); do
      sleep $try
      echo "Running cleanup command $i (try: ${try})"
        eval $i || continue
      break
    done
  done
}

function add_on_exit {
  local n=${#on_exit_items[@]}
  on_exit_items=("${on_exit_items[@]}" "$*")
  if [[ $n -eq 0 ]]; then
    trap on_exit EXIT
  fi
}
