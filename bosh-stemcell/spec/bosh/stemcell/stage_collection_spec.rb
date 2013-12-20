require 'spec_helper'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  describe StageCollection do
    subject(:stage_collection) do
      StageCollection.new(
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent_name: agent_name,
      )
    end

    let(:ubuntu_stages) {
      [
        :base_debootstrap,
        :base_apt,
        :bosh_dpkg_list,
        :bosh_users,
        :bosh_monit,
        :bosh_sysstat,
        :bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
        :rsyslog,
        :system_grub,
        :system_kernel,
      ]
    }

    let(:centos_stages) {
      [
        :base_centos,
        :base_yum,
        :bosh_users,
        :bosh_monit,
        #:bosh_sysstat,
        #:bosh_sysctl,
        :bosh_ntpdate,
        :bosh_sudoers,
        :system_grub,
      #:system_kernel,
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

    let(:openstack_infrastructure_stages) {
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

    let(:vsphere_infrastructure_stages) {
      [
        :system_open_vm_tools,
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
        let(:agent_name) { 'ruby' }
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
              expect(stage_collection.all_stages).to eq(ubuntu_stages +
                                                          agent_stages +
                                                          aws_infrastructure_stages)
            end
          end

          context 'when operating system is Centos' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(centos_stages +
                                                          agent_stages +
                                                          aws_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is OpenStack' do
          let(:infrastructure) { Infrastructure.for('openstack') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(ubuntu_stages +
                                                          agent_stages +
                                                          openstack_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(centos_stages +
                                                          agent_stages +
                                                          openstack_centos_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is vSphere' do
          let(:infrastructure) { Infrastructure.for('vsphere') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(ubuntu_stages +
                                                          agent_stages +
                                                          vsphere_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(centos_stages +
                                                          agent_stages +
                                                          vsphere_centos_infrastructure_stages)
            end
          end
        end
      end

      context 'when using the go agent' do
        let(:agent_name) { 'go' }
        let(:agent_stages) {
          [
            :bosh_go_agent,
            #:bosh_micro,
            :aws_cli,
          ]
        }

        context 'when infrastructure is AWS' do
          let(:infrastructure) { Infrastructure.for('aws') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(ubuntu_stages +
                                                          agent_stages +
                                                          aws_infrastructure_stages)
            end
          end

          context 'when operating system is Centos' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(centos_stages +
                                                          agent_stages +
                                                          aws_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is OpenStack' do
          let(:infrastructure) { Infrastructure.for('openstack') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(ubuntu_stages +
                                                          agent_stages +
                                                          openstack_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(centos_stages +
                                                          agent_stages +
                                                          openstack_centos_infrastructure_stages)
            end
          end
        end

        context 'when infrastructure is vSphere' do
          let(:infrastructure) { Infrastructure.for('vsphere') }

          context 'when operating system is Ubuntu' do
            let(:operating_system) { OperatingSystem.for('ubuntu') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(ubuntu_stages +
                                                          agent_stages +
                                                          vsphere_infrastructure_stages)
            end
          end

          context 'when operating system is CentOS' do
            let(:operating_system) { OperatingSystem.for('centos') }

            it 'has the correct stages' do
              expect(stage_collection.all_stages).to eq(centos_stages +
                                                          agent_stages +
                                                          vsphere_centos_infrastructure_stages)
            end
          end
        end
      end
    end
  end
end
