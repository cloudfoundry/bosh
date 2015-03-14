# Copyright (c) 2009-2012 VMware, Inc.

function disable {
  if [ -e $1 ]
  then
    mv $1 $1.back
    ln -s /bin/true $1
  fi
}

function enable {
  if [ -L $1 ]
  then
    mv $1.back $1
  else
    # No longer a symbolic link, must have been overwritten
    rm -f $1.back
  fi
}

function run_in_chroot {
  local chroot=$1
  local script=$2

  # Disable daemon startup
  disable $chroot/sbin/initctl
  disable $chroot/usr/sbin/invoke-rc.d

  unshare -m $SHELL <<EOS
    mkdir -p $chroot/dev
    mount -n --bind /dev $chroot/dev
    mount -n --bind /dev/pts $chroot/dev/pts

    mkdir -p $chroot/proc
    mount -n --bind /proc $chroot/proc

    chroot $chroot env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin http_proxy=${http_proxy:-} bash -e -c "$script"
EOS

  # Enable daemon startup
  enable $chroot/sbin/initctl
  enable $chroot/usr/sbin/invoke-rc.d
}

declare -a on_exit_items
on_exit_items=()

function on_exit {
  echo "Running ${#on_exit_items[@]} on_exit items..."
  for i in "${on_exit_items[@]}"
  do
    echo "Running $i"
    eval $i
  done
}

function add_on_exit {
  local n=${#on_exit_items[@]}
  on_exit_items[$n]="$*"
  if [[ $n -eq 0 ]]; then
    trap on_exit EXIT
  fi
}
