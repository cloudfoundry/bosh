require 'spec_helper'
require 'bosh/stemcell/arch'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  describe StageCollection do
    subject(:stage_collection) { StageCollection.new(definition) }
    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    end
    let(:agent) { double }
    let(:infrastructure) { double }
    let(:operating_system) { double }

    describe '#operating_system_stages' do
      context 'when Ubuntu' do
        let(:operating_system) { OperatingSystem.for('ubuntu') }

        it 'has the correct stages' do
          expect(stage_collection.operating_system_stages).to eq(
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
              :bosh_sysctl,
              :bosh_limits,
              :bosh_users,
              :bosh_monit,
              :bosh_ntpdate,
              :bosh_sudoers,
              :password_policies,
              :tty_config,
              :rsyslog_config,
              :delay_monit_start,
              :system_grub,
              :vim_tiny,
              :cron_config,
              :escape_ctrl_alt_del,
              :system_users,
              :bosh_audit,
            ].reject{ |s| Bosh::Stemcell::Arch.ppc64le? and s ==  :system_ixgbevf }
          )
        end
      end

      context 'when CentOS 7' do
        let(:operating_system) { OperatingSystem.for('centos', '7') }

        it 'has the correct stages' do
          expect(stage_collection.operating_system_stages).to eq(
            [
              :base_centos,
              :base_runsvdir,
              :base_centos_packages,
              :base_file_permission,
              :base_ssh,
              :system_kernel_modules,
              :system_ixgbevf,
              :bosh_sysctl,
              :bosh_limits,
              :bosh_users,
              :bosh_monit,
              :bosh_ntpdate,
              :bosh_sudoers,
              :password_policies,
              :tty_config,
              :rsyslog_config,
              :delay_monit_start,
              :system_grub,
              :cron_config,
              :escape_ctrl_alt_del,
              :bosh_audit,
            ]
          )
        end
      end

      context 'when RHEL 7' do
        let(:operating_system) { OperatingSystem.for('rhel', '7') }

        it 'has the correct stages' do
          expect(stage_collection.operating_system_stages).to eq(
            [
              :base_rhel,
              :base_runsvdir,
              :base_centos_packages,
              :base_file_permission,
              :base_ssh,
              :system_kernel_modules,
              :bosh_sysctl,
              :bosh_limits,
              :bosh_users,
              :bosh_monit,
              :bosh_ntpdate,
              :bosh_sudoers,
              :rsyslog_config,
              :delay_monit_start,
              :system_grub,
              :rhel_unsubscribe,
              :cron_config,
            ]
          )
        end
      end
    end

    describe '#agent_stages' do
      let(:agent) { Agent.for('go') }

      let(:agent_stages) do
        [
          :bosh_ruby,
          :bosh_go_agent,
          :bosh_micro_go,
          :aws_cli,
          :logrotate_config,
          :dev_tools_config,
        ]
      end

      it 'returns the correct stages' do
        expect(stage_collection.agent_stages).to eq(agent_stages)
      end
    end

    describe '#build_stemcell_image_stages' do
      let(:vmware_package_stemcell_steps) {
        [
          :image_ovf_vmx,
          :image_ovf_generate,
          :prepare_ovf_image_stemcell,
        ]
      }

      context 'when using AWS' do
        let(:infrastructure) { Infrastructure.for('aws') }

        let(:aws_build_stemcell_image_stages) {
          [
            :system_network,
            :system_aws_modules,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_aws_agent_settings,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :image_aws_update_grub,
            :bosh_package_list
          ]
        }

        let(:aws_package_stemcell_stages) {
          [
            :prepare_raw_image_stemcell,
          ]
        }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(aws_build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('raw')).to eq(aws_package_stemcell_stages)
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(aws_build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('raw')).to eq(aws_package_stemcell_stages)
          end

        end
      end

      context 'when using Google' do
        let(:infrastructure) { Infrastructure.for('google') }

        let(:google_build_stemcell_image_stages) {
          [
            :system_network,
            :system_google_modules,
            :system_google_packages,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_google_agent_settings,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :bosh_package_list
          ]
        }

        let(:google_package_stemcell_stages) {
          [
            :prepare_rawdisk_image_stemcell,
          ]
        }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(google_build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('rawdisk')).to eq(google_package_stemcell_stages)
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(google_build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('rawdisk')).to eq(google_package_stemcell_stages)
          end

        end
      end

      context 'when using OpenStack' do
        let(:infrastructure) { Infrastructure.for('openstack') }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_openstack_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list
              ]
            )
            expect(stage_collection.package_stemcell_stages('qcow2')).to eq(
                [
                :prepare_qcow2_image_stemcell,
              ]
            )
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_openstack_clock,
                :system_openstack_modules,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_openstack_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list
              ]
            )
            expect(stage_collection.package_stemcell_stages('qcow2')).to eq(
                [
                  :prepare_qcow2_image_stemcell,
                ]
            )
          end
        end
      end

      context 'when using vSphere' do
        let(:infrastructure) { Infrastructure.for('vsphere') }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_open_vm_tools,
                :system_vsphere_cdrom,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_enable_password_authentication,
                :bosh_vsphere_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list
              ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_open_vm_tools,
                :system_vsphere_cdrom,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_enable_password_authentication,
                :bosh_vsphere_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list
              ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end
      end

      context 'when using vCloud' do
        let(:infrastructure) { Infrastructure.for('vcloud') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_open_vm_tools,
                :system_vsphere_cdrom,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_enable_password_authentication,
                :bosh_vsphere_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list,
            ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end

        context 'when operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_open_vm_tools,
                :system_vsphere_cdrom,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_enable_password_authentication,
                :bosh_vsphere_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list,
              ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end
      end

      context 'when using Azure' do
        let(:infrastructure) { Infrastructure.for('azure') }

        let(:azure_build_stemcell_image_stages) {
          [
            :system_azure_network,
            :system_azure_wala,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_azure_agent_settings,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :bosh_package_list
          ]
        }

        let(:azure_package_stemcell_stages) {
          [
            :prepare_vhd_image_stemcell,
          ]
        }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(azure_build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('vhd')).to eq(azure_package_stemcell_stages)
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(azure_build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('vhd')).to eq(azure_package_stemcell_stages)
          end
        end
      end

      context 'when using softlayer' do
        let(:infrastructure) { Infrastructure.for('softlayer') }

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(
              [
                :system_network,
                :system_softlayer_open_iscsi,
                :system_softlayer_multipath_tools,
                :disable_blank_passwords,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_enable_password_authentication,
                :bosh_softlayer_agent_settings,
                :bosh_clean_ssh,
                :image_create,
                :image_install_grub,
                :bosh_package_list
              ]
            )
            expect(stage_collection.package_stemcell_stages('ovf')).to eq(vmware_package_stemcell_steps)
          end
        end
      end

      context 'when using Warden' do
        let(:infrastructure) { Infrastructure.for('warden') }

        let(:build_stemcell_image_stages) {
          [
            :system_parameters,
            :base_warden,
            :bosh_clean,
            :bosh_harden,
            :bosh_enable_password_authentication,
            :bosh_clean_ssh,
            :image_create,
            :image_install_grub,
            :bosh_package_list
          ]
        }

        let(:package_stemcell_stages) {
          [
            :prepare_files_image_stemcell,
          ]
        }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('files')).to eq(package_stemcell_stages)
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'returns the correct stages' do
            expect(stage_collection.build_stemcell_image_stages).to eq(build_stemcell_image_stages)
            expect(stage_collection.package_stemcell_stages('files')).to eq(package_stemcell_stages)
          end
        end
      end
    end
  end
end
