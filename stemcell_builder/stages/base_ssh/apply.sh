#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

chmod 0600 $chroot/etc/ssh/sshd_config

sed "/^ *UseDNS/d" -i $chroot/etc/ssh/sshd_config
echo 'UseDNS no' >> $chroot/etc/ssh/sshd_config

sed "/^ *PermitRootLogin/d" -i $chroot/etc/ssh/sshd_config
echo 'PermitRootLogin no' >> $chroot/etc/ssh/sshd_config

sed "/^ *X11Forwarding/d" -i $chroot/etc/ssh/sshd_config
sed "/^ *X11DisplayOffset/d" -i $chroot/etc/ssh/sshd_config
echo 'X11Forwarding no' >> $chroot/etc/ssh/sshd_config

sed "/^ *MaxAuthTries/d" -i $chroot/etc/ssh/sshd_config
echo 'MaxAuthTries 3' >> $chroot/etc/ssh/sshd_config

sed "/^ *PermitEmptyPasswords/d" -i $chroot/etc/ssh/sshd_config
echo 'PermitEmptyPasswords no' >> $chroot/etc/ssh/sshd_config

sed "/^ *Protocol/d" -i $chroot/etc/ssh/sshd_config
echo 'Protocol 2' >> $chroot/etc/ssh/sshd_config

sed "/^ *HostbasedAuthentication/d" -i $chroot/etc/ssh/sshd_config
echo 'HostbasedAuthentication no' >> $chroot/etc/ssh/sshd_config

sed "/^ *Banner/d" -i $chroot/etc/ssh/sshd_config
echo 'Banner /etc/issue' >> $chroot/etc/ssh/sshd_config

sed "/^ *IgnoreRhosts/d" -i $chroot/etc/ssh/sshd_config
echo 'IgnoreRhosts yes' >> $chroot/etc/ssh/sshd_config

sed "/^ *ClientAliveInterval/d" -i $chroot/etc/ssh/sshd_config
echo 'ClientAliveInterval 900' >> $chroot/etc/ssh/sshd_config

sed "/^ *PermitUserEnvironment/d" -i $chroot/etc/ssh/sshd_config
echo 'PermitUserEnvironment no' >> $chroot/etc/ssh/sshd_config

sed "/^ *ClientAliveCountMax/d" -i $chroot/etc/ssh/sshd_config
echo 'ClientAliveCountMax 0' >> $chroot/etc/ssh/sshd_config

# protect against as-shipped sshd_config that has no newline at end
echo "" >> $chroot/etc/ssh/sshd_config

# OS Specifics
if [ "$(get_os_type)" == "centos" -o "$(get_os_type)" == "rhel" -o "$(get_os_type)" == "photon" ]; then
  # Allow only 3DES and AES series ciphers
  sed "/^ *Ciphers/d" -i $chroot/etc/ssh/sshd_config
  echo 'Ciphers aes256-ctr,aes192-ctr,aes128-ctr' >> $chroot/etc/ssh/sshd_config

  # Disallow Weak MACs
  sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
  echo 'MACs hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,hmac-sha1' >> $chroot/etc/ssh/sshd_config

elif [ "$(get_os_type)" == "ubuntu" ]; then
  #  Allow only 3DES and AES series ciphers
  sed "/^ *Ciphers/d" -i $chroot/etc/ssh/sshd_config
  echo 'Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr' >> $chroot/etc/ssh/sshd_config

  # Disallow Weak MACs
  sed "/^ *MACs/d" -i $chroot/etc/ssh/sshd_config
  echo 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,hmac-sha1' >> $chroot/etc/ssh/sshd_config

else
  echo "Unknown OS type $(get_os_type)"
  exit 1

fi
