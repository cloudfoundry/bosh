#!/usr/bin/env bash

set -eu -o pipefail

if [ -L /var/vcap/packages/mysql ]
then
  # After the upgrade to mariadb connector 3.1.11, the mariadb_config binary started returned dereferenced symlinks
  # instead of the symlink paths. This breaks the mysql2 gem if you compile the director package on one VM, and then
  # use it on another. No amount of flags (such as --with-mysql-include) seemed to fix the problem. Specifically, the
  # rpaths of the mysql2.so are paths that no longer exist.
  /var/vcap/packages/mysql/bin/mariadb_config "$@" |  sed -e "s@$(readlink /var/vcap/packages/mysql)/@/var/vcap/packages/mysql/@g"
else
  /var/vcap/packages/mysql/bin/mariadb_config "$@"
fi
