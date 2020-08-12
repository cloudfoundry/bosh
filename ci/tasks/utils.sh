#!/usr/bin/env bash

check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

rotate_bbl_certs() {
  for vars_store in $@; do
    local ops=""
    for cert in $(grep "ca: |" -B1 "${vars_store}" | grep -v "ca: |" | grep ':' | cut -d: -f1); do
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
