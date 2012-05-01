# Setup base chroot
stage base_debootstrap
stage base_apt
stage base_warden

# Bosh steps
stage bosh_users
stage bosh_debs
stage bosh_monit
stage bosh_ruby
stage bosh_agent
stage bosh_sysstat
stage bosh_sysctl

# Micro BOSH
if [ ${bosh_micro_enabled:-no} == "yes" ]
then
  stage bosh_micro
fi

# Install GRUB/kernel/etc
stage system_grub
stage system_kernel

# Misc
stage system_aws_network
stage system_parameters

# Finalisation
stage bosh_clean
stage bosh_harden
stage bosh_dpkg_list

# Image/bootloader
stage image_create
stage image_install_grub
stage image_aws_update_grub
stage image_aws_prepare_stemcell

# Final stemcell
stage stemcell
