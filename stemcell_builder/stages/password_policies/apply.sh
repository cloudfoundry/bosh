#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

run_in_chroot $chroot "
  find /etc/pam.d -type f -print0 | xargs -0 sed -i -r 's%\bnullok[^ ]*%%g'
"

# We need to strip the trailing whitespace from the file because some of the
# PAM configuration files in the base image have trailing whitespace which
# causes the patch not to apply.
#
# The patch could just include the whitespace in the outgoing changes but
# editors have a habit of removing trailing whitespace and so this would cause
# the patch to become invalid whenever someone opened one of them.
#
# The some versions of the `patch` command have a `-I` flag to ignore whitespace
# however the image that we're using to build these images has a version
# that does not contain this.
strip_trailing_whitespace_from() {
  sed -i -e's/[[:space:]]*$//' "$1"
}

if [ "$(get_os_type)" == "centos" ]; then
  strip_trailing_whitespace_from $chroot/etc/pam.d/password-auth
  patch $chroot/etc/pam.d/password-auth < $assets_dir/centos/password-auth.patch

  strip_trailing_whitespace_from $chroot/etc/pam.d/system-auth
  patch $chroot/etc/pam.d/system-auth < $assets_dir/centos/system-auth.patch
elif [ "$(get_os_type)" == "ubuntu" ]; then
  strip_trailing_whitespace_from $chroot/etc/pam.d/common-account
  patch $chroot/etc/pam.d/common-account < $assets_dir/ubuntu/common-account.patch

  strip_trailing_whitespace_from $chroot/etc/pam.d/common-auth
  patch $chroot/etc/pam.d/common-auth < $assets_dir/ubuntu/common-auth.patch

  strip_trailing_whitespace_from $chroot/etc/pam.d/common-password
  patch $chroot/etc/pam.d/common-password < $assets_dir/ubuntu/common-password.patch
fi


# /etc/login.defs are only effective for new users
sed -i -r 's/^PASS_MIN_DAYS.+/PASS_MIN_DAYS 1/' $chroot/etc/login.defs
run_in_chroot $chroot "chage --mindays 1 vcap"
