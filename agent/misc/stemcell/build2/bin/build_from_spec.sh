#!/usr/bin/env bash

set -e
[ -n "$DEBUG" ] && set -x

base_dir=$(readlink -nf $(dirname $0)/..)
stages_dir=$base_dir/stages

mnt=$(echo "$1" | sed -e 's#/*$##')
spec=$2
settings_file=$3

function sha1() {
  (
    cd $stages_dir/$1
    find . -type f | sort | xargs -n1 sha1sum | sha1sum
  )
}

function stage_with_btrfs() {
  local stage=$1
  local trace=tmp/trace.sha1sum
  local mnt_work=$mnt/work

  local mnt_after=$mnt/${stage}_applied
  local mnt_trace=$mnt_after/$trace

  local mnt_previous_after=$mnt/${previous_stage}_applied
  local mnt_previous_trace=$mnt_previous_after/$trace

  sha1_expect=$(
    if [ -f $mnt_previous_trace ]
    then
      cat $mnt_previous_trace
    fi

    sha1 $stage
  )

  sha1_actual=$(
    if [ -f $mnt_trace ]
    then
      cat $mnt_trace
    fi
  )

  if [ "$sha1_expect" != "$sha1_actual" ]
  then
    # Destroy "work" subvolume
    if [ -d "$mnt_work" ]
    then
      btrfs subvolume delete $mnt_work
    fi

    # Destroy "applied" subvolume
    if [ -d "$mnt_after" ]
    then
      btrfs subvolume delete $mnt_after
    fi

    # Create new "work" subvolume
    if [ -d "$mnt_previous_after" ]
    then
      btrfs subvolume snapshot $mnt_previous_after $mnt_work
    else
      btrfs subvolume create $mnt_work
    fi

    # Apply stage
    $stages_dir/$stage/apply.sh $mnt_work

    # Add trace
    mkdir -p $(dirname $mnt_work/$trace)
    sha1 $stage >> $mnt_work/$trace

    # Snapshot
    if [ ! -d "$mnt_after" ]
    then
      btrfs subvolume snapshot $mnt_work $mnt_after
      chmod 0755 $mnt_after
    fi
  else
    echo "$stage unchanged, skipping..."
  fi
}

function stage_direct() {
  local stage=$1
  local mnt_work=$mnt/work

  mkdir -p $mnt_work

  # Apply stage
  $stages_dir/$stage/apply.sh $mnt_work
}

# Find out which staging function to use
mnt_type=unknown
if mountpoint -q $mnt
then
  if [ "$(grep $mnt /proc/mounts | cut -d" " -f3)" == "btrfs" ]
  then
   mnt_type=btrfs
  fi
fi

# Generate settings for every stage in the spec
function stage() {
  if [ -x $stages_dir/$1/config.sh ]
  then
    $stages_dir/$1/config.sh $settings_file
  fi
}

source $settings_file
source $spec

previous_stage=

function stage() {
  if [ "$mnt_type" == "btrfs" ]
  then
    stage_with_btrfs $1
  else
    stage_direct $1
  fi

  previous_stage=$1
}

source $settings_file
source $spec
