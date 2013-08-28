#!/usr/bin/env bash

set -e
[ -n "$DEBUG" ] && set -x

base_dir=$(readlink -nf $(dirname $0)/..)
stages_dir=$base_dir/stages

mnt=$(echo "$1" | sed -e 's#/*$##')
spec=$2
settings_file=$3

# Generate settings for every stage in the spec
function stage() {
  echo "=== Configuring '$1' stage ==="
  if [ -x $stages_dir/$1/config.sh ]
  then
    $stages_dir/$1/config.sh $settings_file
  fi
}

source $spec

#################################################

# Apply stage for every stage in the spec
function stage() {
  echo "=== Applying '$1' stage ==="
  echo "== Started $(date) =="

  mkdir -p $mnt/work

  $stages_dir/$1/apply.sh $mnt/work
}

source $spec
