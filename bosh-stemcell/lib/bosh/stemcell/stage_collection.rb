require 'bosh/stemcell/definition'
require 'forwardable'

module Bosh::Stemcell
  class StageCollection
    extend Forwardable

    def initialize(definition)
      @definition = definition
    end

    def all_stages
      operating_system_stages + agent_stages + infrastructure_stages
    end

    private

    def_delegators :@definition, :infrastructure, :operating_system, :agent

    def agent_stages
      case agent
        when Agent::Go
          [
            :bosh_ruby,
            :bosh_go_agent,
            :bosh_micro_go,
            :aws_cli,
          ]
        when Agent::Ruby
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
          centos_os_stages + common_os_stages
        when OperatingSystem::Ubuntu then
          ubuntu_os_stages + common_os_stages
      end
    end

    def infrastructure_stages
      case infrastructure
        when Infrastructure::Aws then
          aws_stages
        when Infrastructure::OpenStack then
          if operating_system.instance_of?(OperatingSystem::Centos)
            centos_openstack_stages
          else
            openstack_stages
          end
        when Infrastructure::Vsphere then
          if operating_system.instance_of?(OperatingSystem::Centos)
            centos_vsphere_stages
          else
            vsphere_stages
          end
      end
    end

    def centos_os_stages
      [:base_centos, :base_yum]
    end

    def ubuntu_os_stages
      [
        :base_debootstrap,
        :base_apt,
        :bosh_dpkg_list,
        :bosh_sysstat,
        :bosh_sysctl,
        :system_kernel,
      ]
    end

    def common_os_stages
      [
        # Bosh steps
        :bosh_users,
        :bosh_monit,
        :bosh_ntpdate,
        :bosh_sudoers,
        :rsyslog,
        # Install GRUB/kernel/etc
        :system_grub,
      ]
    end

    def centos_vsphere_stages
      [
        #:system_open_vm_tools,
        :system_vsphere_cdrom,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        :stemcell,
      ]
    end

    def centos_openstack_stages
      [
        # Misc
        :system_openstack_network_centos,
        :system_parameters,
        # Finalisation,
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        # Final stemcell
        :stemcell_openstack,
      ]
    end

    def aws_stages
      [
        # Misc
        :system_aws_network,
        :system_aws_modules,
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_aws_update_grub,
        :image_aws_prepare_stemcell,
        # Final stemcell
        :stemcell,
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
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        # Final stemcell
        :stemcell_openstack,
      ]
    end

    def vsphere_stages
      [
        :system_open_vm_tools,
        :system_vsphere_cdrom,
        # Misc
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        # Final stemcell
        :stemcell,
      ]
    end
  end
end
