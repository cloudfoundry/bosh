#!/bin/bash

set -ex

cd /tmp
echo "${OVF_TOOL_INSTALLER_SHA1} /tmp/ovftool_installer.bundle" | sha1sum -c -
chmod a+x ./ovftool_installer.bundle
ln -s /bin/cat /usr/local/bin/more
echo -e "\nyes\n\n" | bash  ./ovftool_installer.bundle
rm -rf ./ovftool_installer.bundle /tmp/vmware-root/ /usr/local/bin/more
