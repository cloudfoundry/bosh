#!/bin/bash

function run_in_chroot {
  # Need to explicitly override LANG and LC_ALL so that they aren't
  # inherited from the environment.
  chroot $1 env LANG='C' LC_ALL='C' sh -c "$2"
}

# Taken from http://www.linuxjournal.com/content/use-bash-trap-statement-cleanup-temporary-files
declare -a on_exit_items

function on_exit {
  for i in "${on_exit_items[@]}"
  do
    eval $i
  done
}

function add_on_exit {
  local n=${#on_exit_items[*]}
  on_exit_items[$n]="$*"
  if [[ $n -eq 0 ]]; then
    trap on_exit EXIT
  fi
}

function disable_daemon_startup {
  target=$1
  skeleton=$2

  echo "Configuring fake initctl"
  mv $target/sbin/initctl $target/sbin/initctl.back
  cp $skeleton/sbin/initctl-stub $target/sbin/initctl
  chmod 0755 $target/sbin/initctl

  echo "Configuring nostart policy"
  cp $skeleton/usr/sbin/nostart-policy-rc.d $target/usr/sbin/policy-rc.d
  chmod 0755 $target/usr/sbin/policy-rc.d
}

function enable_daemon_startup {
  target=$1

  echo "Removing fake initctl"
  mv ${target}/sbin/initctl.back ${target}/sbin/initctl

  echo "Removing nostart policy"
  rm $target/usr/sbin/policy-rc.d
}