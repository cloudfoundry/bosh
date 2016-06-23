#!/bin/sh

# only if interactive
[ ! -z "$PS1" ] || return

case "${TERM:-}" in
  xterm-color)
    color_prompt=yes
    ;;
  *)
    # fallback to term capabilities check
    ! tput setaf 1 >&/dev/null || color_prompt=yes
    ;;
esac

bosh_instance=$( cat /var/vcap/instance/name )/$( cat /var/vcap/instance/id )

if [ "${color_prompt:-}" = yes ]; then
    PS1="\\[\\033[01;32m\\]$bosh_instance\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\\$ "
else
    PS1="$bosh_instance:\\w\\\$ "
fi

unset color_prompt

case "${TERM:-}" in
  xterm*|rxvt*)
    # hinting the window title with instance and working directory
    PS1="\\[\\e]0;$bosh_instance:\\w\\a\\]$PS1"
    ;;
esac

unset bosh_instance
