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

stage bosh_micro

stage mcf_version
stage mcf_dirs

# Install GRUB/kernel/etc
stage system_grub
stage system_kernel
stage system_open_vm_tools

# Misc
stage mcf_network
stage system_parameters

# Finalisation
stage bosh_clean
stage bosh_harden
stage bosh_dpkg_list

# Image/bootloader
stage image_create
stage image_install_grub
stage mcf_vmx
stage image_vsphere_ovf
stage mcf_package
