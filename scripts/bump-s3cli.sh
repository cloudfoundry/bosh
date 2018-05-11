#!/usr/bin/env bash

set -e

function main() {
  local current_version=${1?'Current version is required.'}
  local file_sha=${2?'shasum is required.'}

  local current_file_name="s3cli-${current_version}-linux-amd64"

  wget -O "${current_file_name}" "https://s3.amazonaws.com/s3cli-artifacts/${current_file_name}"
  echo "${file_sha}  ${current_file_name}" | shasum -c

  update_blobs ${current_file_name}

  rm "${current_file_name}"
}

function update_blobs() {
  local current_file_name=${1?'Current file is required.'}

  bosh remove-blob "$( bosh blobs --column=path | grep s3cli | tr -d '[:space:]' )"

  load_private_yml
  bosh add-blob ${current_file_name} s3cli/${current_file_name}
  bosh upload-blobs
  delete_private_yml
}

function load_private_yml() {
  lpass show --notes 'BOSH release blobs private config' > config/private.yml
}

function delete_private_yml() {
  rm config/private.yml
}

main ${1} ${2}
