require 'bosh/stemcell/definition'
require 'forwardable'

module Bosh::Stemcell
  class StageCollection
    extend Forwardable

    def initialize(definition)
      @definition = definition
    end

    def operating_system_stages
      case operating_system
      when OperatingSystem::Centos then
        centos_os_stages
      when OperatingSystem::Ubuntu then
        ubuntu_os_stages
      end
    end

    def extract_operating_system_stages
      [
        :untar_base_os_image,
      ]
    end

    def agent_stages
      [
        :bosh_ruby,
        :bosh_go_agent,
        :bosh_micro_go,
        :aws_cli,
      ]
    end

    def infrastructure_stages
      case infrastructure
      when Infrastructure::Aws then
        aws_stages
      when Infrastructure::OpenStack then
        openstack_stages
      when Infrastructure::Vsphere then
        vsphere_stages
      when Infrastructure::Vcloud then
        vcloud_stages
      when Infrastructure::Warden then
        warden_stages
      end
    end

    def openstack_stages
      if operating_system.instance_of?(OperatingSystem::Centos)
        centos_openstack_stages
      else
        default_openstack_stages
      end
    end

    def vsphere_stages
      if operating_system.instance_of?(OperatingSystem::Centos)
        centos_vsphere_stages
      else
        default_vsphere_stages
      end
    end

    def vcloud_stages
      if operating_system.instance_of?(OperatingSystem::Centos)
        centos_vcloud_stages
      else
        default_vcloud_stages
      end
    end

    private

    def_delegators :@definition, :infrastructure, :operating_system, :agent

    def centos_os_stages
      [
        :base_centos,
        :base_centos_packages,
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

    def ubuntu_os_stages
      [
        :base_debootstrap,
        :base_ubuntu_firstboot,
        :base_apt,
        :base_ubuntu_build_essential,
        :base_ubuntu_packages,
        :bosh_dpkg_list,
        :bosh_sysstat,
        :bosh_sysctl,
        :system_kernel,
        :system_rescan_scsi_bus,
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
        :image_ovf_vmx,
        :image_ovf_generate,
        :image_ovf_prepare_stemcell,
        :stemcell,
      ]
    end

    def centos_vcloud_stages
      [
        #:system_open_vm_tools,
        :system_vsphere_cdrom,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :image_create,
        :image_install_grub,
        :image_ovf_vmx,
        :image_ovf_generate,
        :image_ovf_prepare_stemcell,
        :stemcell
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
        :bosh_openstack_agent_settings,
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

    def default_openstack_stages
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
        :bosh_openstack_agent_settings,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        # Final stemcell
        :stemcell_openstack,
      ]
    end

    def default_vsphere_stages
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
        :image_ovf_vmx,
        :image_ovf_generate,
        :image_ovf_prepare_stemcell,
        # Final stemcell
        :stemcell,
      ]
    end

    def default_vcloud_stages
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
        :image_ovf_vmx,
        :image_ovf_generate,
        :image_ovf_prepare_stemcell,
        # Final stemcell
        :stemcell
      ]
    end

    def warden_stages
      [
        :system_parameters,
        :base_warden,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        # Image copy
        :bosh_copy_root,
        # only used for spec test
        :image_create,
        # Final stemcell
        :stemcell,
      ]
    end
  end
end
