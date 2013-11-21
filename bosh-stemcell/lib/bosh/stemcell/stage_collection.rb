require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  class StageCollection

    def initialize(options)
      @infrastructure = options.fetch(:infrastructure)
      @operating_system = options.fetch(:operating_system)
      @agent_name = options.fetch(:agent_name)
    end

    def all_stages
      operating_system_stages + agent_stages + infrastructure_stages
    end

    private

    attr_reader :infrastructure, :operating_system, :agent_name

    def agent_stages
      case agent_name
        when 'go'
          [
            :bosh_go_agent,
            #:bosh_micro,
          ]
        else
          [
            :bosh_ruby,
            :bosh_agent,
            :bosh_micro,
          ]
      end
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
        when Infrastructure::CloudStack then
          cloudstack_stages
      end
    end

    def hacked_centos_common
      [
        # Bosh steps
        :bosh_users,
        :bosh_monit,
        #:bosh_sysstat,
        #:bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
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
        :bosh_harden,
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
        :bosh_sysstat,
        :bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
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

    def cloudstack_stages
      [
        # Misc
        :system_appendix_cloudstack,
        :system_cloudstack_network,
        :system_cloudstack_clock,
        :system_cloudstack_modules,
        :system_parameters,
        # Finalisation,
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :bosh_dpkg_list,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_cloudstack_prepare_stemcell,
        # Final stemcell
        :stemcell_cloudstack
      ]
    end
  end
end
