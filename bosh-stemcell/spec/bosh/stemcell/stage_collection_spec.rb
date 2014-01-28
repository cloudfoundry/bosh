require 'spec_helper'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  describe StageCollection do
    subject(:stage_collection) do
      StageCollection.new(definition)
    end

    let(:definition) {
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    }

    let(:ubuntu_stages) {
      [
        :base_debootstrap,
        :base_apt,
        :bosh_dpkg_list,
        :bosh_sysstat,
        :bosh_sysctl,
        :system_kernel,
        :bosh_users,
        :bosh_monit,
        :bosh_ntpdate,
        :bosh_sudoers,
        :rsyslog,
        :system_grub,
      ]
    }

    let(:centos_stages) {
      [
        :base_centos,
        :base_yum,
        :bosh_users,
        :bosh_monit,
        :bosh_ntpdate,
        :bosh_sudoers,
        :rsyslog,
        :system_grub,
      ]
    }

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

    let(:openstack_ubuntu_infrastructure_stages) {
      [
        :system_openstack_network,
        :system_openstack_clock,
        :system_openstack_modules,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        :stemcell_openstack
      ]
    }

    let(:openstack_centos_infrastructure_stages) {
      [
        :system_openstack_network_centos,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :bosh_harden_ssh,
        :image_create,
        :image_install_grub,
        :image_openstack_qcow2,
        :image_openstack_prepare_stemcell,
        :stemcell_openstack
      ]
    }

    let(:vsphere_ubuntu_infrastructure_stages) {
      [
        :system_open_vm_tools,
        :system_vsphere_cdrom,
        :system_parameters,
        :bosh_clean,
        :bosh_harden,
        :image_create,
        :image_install_grub,
        :image_vsphere_vmx,
        :image_vsphere_ovf,
        :image_vsphere_prepare_stemcell,
        :stemcell
      ]
    }

    let(:vsphere_centos_infrastructure_stages) {
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
        :stemcell
      ]
    }

    describe '#all_stages' do
      context 'when using the ruby agent' do
        let(:agent) { Agent.for('ruby') }
        let(:agent_stages) {
          [
            :bosh_ruby,
            :bosh_agent,
            :bosh_micro,
          ]
        }

        context 'when infrastructure is AWS' do
          let(:infrastructure) { Infrastructure.for('aws') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(ubuntu_stages + agent_stages + aws_infrastructure_stages)
            end
          end

          context 'when operating system is Centos' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(centos_stages + agent_stages + aws_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is OpenStack' do
          let(:infrastructure) { Infrastructure.for('openstack') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(ubuntu_stages + agent_stages + openstack_ubuntu_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(centos_stages + agent_stages + openstack_centos_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is vSphere' do
          let(:infrastructure) { Infrastructure.for('vsphere') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(ubuntu_stages + agent_stages + vsphere_ubuntu_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
              .to eq(centos_stages + agent_stages + vsphere_centos_infrastructure_stages)
            end
          end
        end
      end

      context 'when using the go agent' do
        let(:agent) { Agent.for('go') }
        let(:agent_stages) {
          [
            :bosh_ruby,
            :bosh_go_agent,
            :bosh_micro_go,
            :aws_cli,
          ]
        }

        context 'when infrastructure is AWS' do
          let(:infrastructure) { Infrastructure.for('aws') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(ubuntu_stages + agent_stages + aws_infrastructure_stages)
            end
          end

          context 'when operating system is Centos' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(centos_stages + agent_stages + aws_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is OpenStack' do
          let(:infrastructure) { Infrastructure.for('openstack') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(ubuntu_stages + agent_stages + openstack_ubuntu_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(centos_stages + agent_stages + openstack_centos_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is vSphere' do
          let(:infrastructure) { Infrastructure.for('vsphere') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(ubuntu_stages + agent_stages + vsphere_ubuntu_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages)
                .to eq(centos_stages + agent_stages + vsphere_centos_infrastructure_stages)
            end
          end
        end
      end
    end
  end
end
