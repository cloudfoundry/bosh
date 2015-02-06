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
        :logrotate_config,
      ]
    end

    def build_stemcell_image_stages
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

    def package_stemcell_stages(disk_format)
      case disk_format
        when 'raw' then
          raw_package_stages
        when 'qcow2' then
          qcow2_package_stages
        when 'ovf' then
          ovf_package_stages
        when 'files' then
          files_package_stages
      end
    end

    private

    def_delegators :@definition, :infrastructure, :operating_system, :agent

    def openstack_stages
      if operating_system.instance_of?(OperatingSystem::Centos)
        centos_openstack_stages
      else
        ubuntu_openstack_stages
      end
    end

    def vsphere_stages
      if operating_system.instance_of?(OperatingSystem::Centos)
        centos_vmware_stages
      else
        ubuntu_vmware_stages
      end
    end

    def vcloud_stages
      if operating_system.instance_of?(OperatingSystem::Centos)
        centos_vmware_stages
      else
        ubuntu_vmware_stages
      end
    end

    def centos_os_stages
      [
        :base_centos,
        :base_centos_packages,
        :base_ssh,
        # Bosh steps
        :bosh_users,
        :bosh_monit,
        :bosh_ntpdate,
        :bosh_sudoers,
        :rsyslog,
        :delay_monit_start,
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
        :base_ssh,
        :bosh_dpkg_list,
        :bosh_sysstat,
        :bosh_sysctl,
        :system_kernel,
        # Bosh steps
        :bosh_users,
        :bosh_monit,
        :bosh_ntpdate,
        :bosh_sudoers,
        :rsyslog,
        :delay_monit_start,
        # Install GRUB/kernel/etc
        :system_grub,
        # Symlink vim to vim.tiny
        :vim_tiny,
      ]
    end

    def centos_vmware_stages
      [
        #:system_open_vm_tools,
        :system_vsphere_cdrom,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :image_create,
        :image_install_grub,
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
        :bosh_aws_agent_settings,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_aws_update_grub,
      ]
    end

    def ubuntu_openstack_stages
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
      ]
    end

    def ubuntu_vmware_stages
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
      ]
    end

    def warden_stages
      [
        :system_parameters,
        :base_warden,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        # only used for spec test
        :image_create,
      ]
    end

    def raw_package_stages
      [
        :prepare_raw_image_stemcell,
      ]
    end

    def qcow2_package_stages
      [
        :prepare_qcow2_image_stemcell,
      ]
    end

    def ovf_package_stages
      [
        :image_ovf_vmx,
        :image_ovf_generate,
        :prepare_ovf_image_stemcell,
      ]
    end

    def files_package_stages
      [
        :prepare_files_image_stemcell,
      ]
    end

  end
end
