require 'spec_helper'
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
              :bosh_dpkg_list,
              :bosh_sysstat,
              :bosh_sysctl,
              :system_kernel,
              :system_rescan_scsi_bus,
              :bosh_users,
              :bosh_monit,
              :bosh_ntpdate,
              :bosh_sudoers,
              :rsyslog,
              :system_grub,
            ]
          )
        end
      end

      context 'when CentOS' do
        let(:operating_system) { OperatingSystem.for('centos') }

        it 'has the correct stages' do
          expect(stage_collection.operating_system_stages).to eq(
            [
              :base_centos,
              :base_centos_packages,
              :bosh_users,
              :bosh_monit,
              :bosh_ntpdate,
              :bosh_sudoers,
              :rsyslog,
              :system_grub,
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
        ]
      end

      it 'returns the correct stages' do
        expect(stage_collection.agent_stages).to eq(agent_stages)
      end
    end

    describe '#infrastructure_stages' do
      context 'when using AWS' do
        let(:infrastructure) { Infrastructure.for('aws') }

        let(:aws_infrastructure_stages) {
          [
            :system_aws_network,
            :system_aws_modules,
            :system_parameters,
            :bosh_clean,
            :bosh_harden,
            :bosh_harden_ssh,
            :image_create,
            :image_install_grub,
            :image_aws_update_grub,
            :image_aws_prepare_stemcell,
            :stemcell
          ]
        }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'returns the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(aws_infrastructure_stages)
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'returns the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(aws_infrastructure_stages)
          end

        end
      end

      context 'when using OpenStack' do
        let(:infrastructure) { Infrastructure.for('openstack') }

        context 'when the operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(
              [
                :system_openstack_network_centos,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_harden_ssh,
                :bosh_openstack_agent_settings,
                :image_create,
                :image_install_grub,
                :image_openstack_qcow2,
                :image_openstack_prepare_stemcell,
                :stemcell_openstack
              ]
            )
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(
              [
                :system_openstack_network,
                :system_openstack_clock,
                :system_openstack_modules,
                :system_parameters,
                :bosh_clean,
                :bosh_harden,
                :bosh_harden_ssh,
                :bosh_openstack_agent_settings,
                :image_create,
                :image_install_grub,
                :image_openstack_qcow2,
                :image_openstack_prepare_stemcell,
                :stemcell_openstack
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
            expect(stage_collection.infrastructure_stages).to eq(
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
            )
          end
        end

        context 'when the operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(
              [
                :system_open_vm_tools,
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
            )
          end
        end
      end

      context 'when using vCloud' do
        let(:infrastructure) { Infrastructure.for('vcloud') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(
              [
                :system_open_vm_tools,
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
            )
          end
        end

        context 'when operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq(
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
            )
          end
        end
      end
    end
  end
end
