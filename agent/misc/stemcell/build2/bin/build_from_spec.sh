#!/usr/bin/env bash

set -e
[ -n "$DEBUG" ] && set -x

base_dir=$(readlink -nf $(dirname $0)/..)
stages_dir=$base_dir/stages

spec=$1
mnt=$2

#function rollback_stage() {
#  local stage=$1
#  local mnt_work=$mnt/work
#  local mnt_before=$mnt/$(basename $stage)_before
#  local mnt_after=$mnt/$(basename $stage)_after
#
#  # Revert to "before" state of this stage
#  if [ -d "$mnt_before" ]
#  then
#    if [ -d "$mnt_work" ]
#    then
#      btrfs subvolume delete $mnt_work
#    fi
#
#    mv $mnt_before $mnt_work
#  fi
#}
#
#function run_stage() {
#  local stage=$1
#  local mnt_work=$mnt/work
#  local mnt_before=$mnt/$(basename $stage)_before
#  local mnt_after=$mnt/$(basename $stage)_after
#
#  # Create subvolume if it doesn't exist
#  if [ ! -d "$mnt_work" ]
#  then
#    btrfs subvolume create $mnt_work
#  fi
#
#  # Snapshot state
#  if [ ! -d "$mnt_before" ]
#  then
#    btrfs subvolume snapshot $mnt_work $mnt_before
#  fi
#
#  # Apply stage
#  $stage/apply.sh $mnt/work
#
#  # Snapshot state
#  if [ ! -d "$mnt_after" ]
#  then
#    btrfs subvolume snapshot $mnt_work $mnt_after
#  fi
#}

function sha1() {
  (
    cd $stages_dir/$1
    find . -type f | sort | xargs -n1 sha1sum | sha1sum
  )
}

previous_stage=

function stage() {
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

  previous_stage=$stage
}

source $spec
