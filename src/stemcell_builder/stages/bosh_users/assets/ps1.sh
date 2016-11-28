#!/bin/sh

# only if interactive
[ ! -z "$PS1" ] || return

bosh_instance="$( cat /var/vcap/instance/name )/$( cat /var/vcap/instance/id )"

PS1="$bosh_instance:\\w\\\$ "

unset bosh_instance
