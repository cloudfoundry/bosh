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
stage bosh_ntpdate
stage bosh_sudoers

# Micro BOSH
if [ ${bosh_micro_enabled:-no} == "yes" ]
then
  stage bosh_micro
fi

# Install GRUB/kernel/etc
stage system_grub
stage system_kernel

# Misc
stage system_openstack_network
stage system_openstack_clock
stage system_openstack_modules
stage system_parameters

# Finalisation
stage bosh_clean
stage bosh_harden
stage bosh_dpkg_list

# Image/bootloader
stage image_create
stage image_install_grub
if [ ${stemcell_hypervisor:-kvm} == "xen" ]
then
  stage image_openstack_update_grub
else
  stage image_openstack_extract_partition
  stage image_openstack_extract_kernel_ramdisk
fi
stage image_openstack_prepare_stemcell

# Final stemcell
stage stemcell_openstack