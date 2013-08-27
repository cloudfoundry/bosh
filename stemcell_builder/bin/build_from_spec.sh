#!/usr/bin/env bash

set -e
[ -n "$DEBUG" ] && set -x

base_dir=$(readlink -nf $(dirname $0)/..)
stages_dir=$base_dir/stages

mnt=$(echo "$1" | sed -e 's#/*$##')
spec=$2
settings_file=$3

function stage_direct() {
  local stage=$1
  local mnt_work=$mnt/work

  mkdir -p $mnt_work

  # Apply stage
  $stages_dir/$stage/apply.sh $mnt_work
}

# Generate settings for every stage in the spec
function stage() {
  echo "=== Configuring '$1' stage ==="
  if [ -x $stages_dir/$1/config.sh ]
  then
    $stages_dir/$1/config.sh $settings_file
  fi
}

source $settings_file
source $spec

previous_stage=

function stage() {
  echo "=== Applying '$1' stage ==="
  echo "== Started $(date) =="
  stage_direct $1

  previous_stage=$1
}

source $settings_file
source $spec
