require 'bosh/stemcell/definition'
require 'forwardable'

# rubocop:disable MethodLength
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
        when OperatingSystem::Rhel then
          rhel_os_stages
        when OperatingSystem::Ubuntu then
          ubuntu_os_stages
        when OperatingSystem::Photon then
          photon_os_stages
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
      stages = case infrastructure
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

      stages.concat(finish_stemcell_stages)
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
      if is_centos? || is_rhel?
        [
          :system_network,
          # Misc
          :system_parameters,
          # Finalisation,
          :bosh_clean,
          :bosh_harden,
          :bosh_disable_password_authentication,
          :bosh_openstack_agent_settings,
          :disable_blank_passwords,
          :image_create,
          :image_install_grub,
        ]
      else
        [
          :system_network,
          # Misc
          :system_openstack_clock,
          :system_openstack_modules,
          :system_parameters,
          # Finalisation,
          :bosh_clean,
          :bosh_harden,
          :bosh_disable_password_authentication,
          :bosh_openstack_agent_settings,
          :disable_blank_passwords,
          # Image/bootloader
          :image_create,
          :image_install_grub,
        ]
      end
    end

    def finish_stemcell_stages
      [
        :bosh_package_list
      ]
    end

    def vsphere_stages
      if is_centos?
        [
          :system_network,
          :system_open_vm_tools,
          :system_vsphere_cdrom,
          :system_parameters,
          :bosh_clean,
          :bosh_harden,
          :bosh_vsphere_agent_settings,
          :disable_blank_passwords,
          :image_create,
          :image_install_grub,
        ]
      else
        [
          :system_network,
          :system_open_vm_tools,
          :system_vsphere_cdrom,
          # Misc
          :system_parameters,
          # Finalisation
          :bosh_clean,
          :bosh_harden,
          :bosh_vsphere_agent_settings,
          :disable_blank_passwords,
          # Image/bootloader
          :image_create,
          :image_install_grub,
        ]
      end
    end

    def vcloud_stages
      if is_centos?
        [
          :system_network,
          :system_open_vm_tools,
          :system_vsphere_cdrom,
          :system_parameters,
          :bosh_clean,
          :bosh_harden,
          :bosh_vsphere_agent_settings,
          :disable_blank_passwords,
          :image_create,
          :image_install_grub,
        ]
      else
        [
          :system_network,
          :system_open_vm_tools,
          :system_vsphere_cdrom,
          # Misc
          :system_parameters,
          # Finalisation
          :bosh_clean,
          :bosh_harden,
          :bosh_vsphere_agent_settings,
          :disable_blank_passwords,
          # Image/bootloader
          :image_create,
          :image_install_grub,
        ]
      end
    end

    def aws_stages
      [
        # Misc
        :system_network,
        :system_aws_modules,
        :system_parameters,
        # Finalisation
        :bosh_clean,
        :bosh_harden,
        :bosh_disable_password_authentication,
        :bosh_aws_agent_settings,
        :disable_blank_passwords,
        # Image/bootloader
        :image_create,
        :image_install_grub,
        :image_aws_update_grub,
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

    def centos_os_stages
     [
        :base_centos,
        :base_centos_packages,
        :base_file_permission,
        :base_ssh,
        :system_kernel_modules,
        :system_ixgbevf,
        bosh_steps,
        :rsyslog_config,
        :delay_monit_start,
        :system_grub,
        :cron_config,
        :escape_ctrl_alt_del
      ].flatten
    end

    def rhel_os_stages
      [
        :base_rhel,
        :base_centos_packages,
        :base_file_permission,
        :base_ssh,
        :system_kernel_modules,
        bosh_steps,
        :rsyslog_config,
        :delay_monit_start,
        :system_grub,
        :rhel_unsubscribe,
        :cron_config,
      ].flatten
    end

    def ubuntu_os_stages
      [
        :base_debootstrap,
        :base_ubuntu_firstboot,
        :base_apt,
        :base_ubuntu_build_essential,
        :base_ubuntu_packages,
        :base_file_permission,
        :base_ssh,
        :bosh_sysstat,
        :system_kernel,
        :system_kernel_modules,
        :system_ixgbevf,
        bosh_steps,
        :rsyslog_config,
        :delay_monit_start,
        :system_grub,
        :vim_tiny,
        :cron_config,
        :escape_ctrl_alt_del,
      ].flatten
    end

    def photon_os_stages
      [
        :base_photon,
        :base_file_permission,
        bosh_steps,
        :base_ssh,
        :rsyslog_config,
        :delay_monit_start,
        :system_grub,
        :cron_config,
      ].flatten
    end

    def bosh_steps
      [
          :bosh_sysctl,
          :bosh_users,
          :bosh_monit,
          :bosh_ntpdate,
          :bosh_sudoers,
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

    def is_centos?
      operating_system.instance_of?(OperatingSystem::Centos)
    end

    def is_rhel?
      operating_system.instance_of?(OperatingSystem::Rhel)
    end
  end
end
