#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/stages/bosh_audit/shared_functions.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install auditd

# Without this, auditd will read from /etc/audit/audit.rules instead
# of /etc/audit/rules.d/*.
sed -i 's/^USE_AUGENRULES="[Nn][Oo]"$/USE_AUGENRULES="yes"/' $chroot/etc/default/auditd
run_in_bosh_chroot $chroot "update-rc.d auditd disable"

write_shared_audit_rules

record_use_of_privileged_binaries

make_audit_rules_immutable

override_default_audit_variables
