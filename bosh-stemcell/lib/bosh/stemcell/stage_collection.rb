require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  class StageCollection

    def initialize(options)
      @infrastructure   = options.fetch(:infrastructure)
      @operating_system = options.fetch(:operating_system)
    end

    def operating_system_stages
      case operating_system
        when OperatingSystem::Centos then
          [:base_centos, :base_yum] + hacked_centos_common
        when OperatingSystem::Ubuntu then
          [:base_debootstrap, :base_apt] + common_stages
      end
    end

    def infrastructure_stages
      case infrastructure
        when Infrastructure::Aws then
          aws_stages
        when Infrastructure::OpenStack then
          openstack_stages
        when Infrastructure::Vsphere then
          operating_system.instance_of?(OperatingSystem::Centos) ? hacked_centos_vsphere : vsphere_stages
      end
    end

    private

    attr_reader :infrastructure, :operating_system

    def hacked_centos_common
      [
        # Bosh steps
        :bosh_users,
        :bosh_monit,
        :bosh_ruby,
        :bosh_agent,
        #:bosh_sysstat,
        #:bosh_sysctl,
        #:bosh_ntpdate,
        #:bosh_sudoers,
        # Micro BOSH
        #:bosh_micro,
        # Install GRUB/kernel/etc
        :system_grub,
        #:system_kernel,
      ]
    end

    def hacked_centos_vsphere
      [
        #:system_open_vm_tools,
        :system_parameters,
        :bosh_clean,
        #:bosh_harden,
        #:bosh_tripwire,
        #:bosh_dpkg_list,
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        :stemcell
      ]
    end

    def common_stages
      [
        # Bosh steps
        :bosh_users,
        :bosh_monit,
        :bosh_ruby,
        :bosh_agent,
        :bosh_sysstat,
        :bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
        # Micro BOSH
        :bosh_micro,
        # Install GRUB/kernel/etc
        :system_grub,
        :system_kernel,
      ]
    end

    def aws_stages
      [
        # Misc
        :system_aws_network,
        :system_aws_clock,
        :system_aws_modules,
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :bosh_tripwire,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_aws_update_grub,
        :image_aws_prepare_stemcell,
        # Final stemcell
        :stemcell
      ]
    end

    def openstack_stages
      [
        # Misc
        :system_openstack_network,
        :system_openstack_clock,
        :system_openstack_modules,
        :system_parameters,
        # Finalisation,
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :bosh_tripwire,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        # Final stemcell
        :stemcell_openstack
      ]
    end

    def vsphere_stages
      [
        :system_open_vm_tools,
        # Misc
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        :bosh_tripwire,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        # Final stemcell
        :stemcell
      ]
    end
  end
end
