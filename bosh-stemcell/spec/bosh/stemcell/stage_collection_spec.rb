require 'spec_helper'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  describe StageCollection do
    subject(:stage_collection) do
      StageCollection.new(infrastructure:   infrastructure,
                          operating_system: operating_system)
    end

    describe '#operating_system_stages' do
      context 'when infrastructure is AWS' do
        let(:infrastructure) { Infrastructure.for('aws') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.operating_system_stages).to eq([
                                                                     :base_debootstrap,
                                                                     :base_apt,
                                                                     :bosh_users,
                                                                     :bosh_monit,
                                                                     :bosh_ruby,
                                                                     :bosh_agent,
                                                                     :bosh_sysstat,
                                                                     :bosh_sysctl,
                                                                     :bosh_ntpdate,
                                                                     :bosh_sudoers,
                                                                     :bosh_micro,
                                                                     :system_grub,
                                                                     :system_kernel,
                                                                   ])
          end
        end
      end

      context 'when infrastructure is OpenStack' do
        let(:infrastructure) { Infrastructure.for('openstack') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.operating_system_stages).to eq([
                                                                     :base_debootstrap,
                                                                     :base_apt,
                                                                     :bosh_users,
                                                                     :bosh_monit,
                                                                     :bosh_ruby,
                                                                     :bosh_agent,
                                                                     :bosh_sysstat,
                                                                     :bosh_sysctl,
                                                                     :bosh_ntpdate,
                                                                     :bosh_sudoers,
                                                                     :bosh_micro,
                                                                     :system_grub,
                                                                     :system_kernel,
                                                                   ])
          end
        end
      end

      context 'when infrastructure is vSphere' do
        let(:infrastructure) { Infrastructure.for('vsphere') }

        context 'when operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.operating_system_stages).to eq([
                                                                     :base_centos,
                                                                     :base_yum,
                                                                     :bosh_users,
                                                                     :bosh_monit,
                                                                     :bosh_ruby,
                                                                     :bosh_agent,
                                                                     #:bosh_sysstat,
                                                                     #:bosh_sysctl,
                                                                     #:bosh_ntpdate,
                                                                     #:bosh_sudoers,
                                                                     #:bosh_micro,
                                                                     :system_grub,
                                                                   #:system_kernel,
                                                                   ])
          end
        end

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.operating_system_stages).to eq([
                                                                     :base_debootstrap,
                                                                     :base_apt,
                                                                     :bosh_users,
                                                                     :bosh_monit,
                                                                     :bosh_ruby,
                                                                     :bosh_agent,
                                                                     :bosh_sysstat,
                                                                     :bosh_sysctl,
                                                                     :bosh_ntpdate,
                                                                     :bosh_sudoers,
                                                                     :bosh_micro,
                                                                     :system_grub,
                                                                     :system_kernel,
                                                                   ])
          end
        end
      end
    end

    describe '#infrastructure_stages' do
      context 'when infrastructure is AWS' do
        let(:infrastructure) { Infrastructure.for('aws') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq([
                                                                   :system_aws_network,
                                                                   :system_aws_clock,
                                                                   :system_aws_modules,
                                                                   :system_parameters,
                                                                   :bosh_clean,
                                                                   :bosh_harden,
                                                                   :bosh_harden_ssh,
                                                                   :bosh_tripwire,
                                                                   :bosh_dpkg_list,
                                                                   :image_create,
                                                                   :image_install_grub,
                                                                   :image_aws_update_grub,
                                                                   :image_aws_prepare_stemcell,
                                                                   :stemcell
                                                                 ])
          end
        end
      end

      context 'when infrastructure is OpenStack' do
        let(:infrastructure) { Infrastructure.for('openstack') }

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq([
                                                                   :system_openstack_network,
                                                                   :system_openstack_clock,
                                                                   :system_openstack_modules,
                                                                   :system_parameters,
                                                                   :bosh_clean,
                                                                   :bosh_harden,
                                                                   :bosh_harden_ssh,
                                                                   :bosh_tripwire,
                                                                   :bosh_dpkg_list,
                                                                   :image_create,
                                                                   :image_install_grub,
                                                                   :image_openstack_qcow2,
                                                                   :image_openstack_prepare_stemcell,
                                                                   :stemcell_openstack
                                                                 ])
          end
        end
      end

      context 'when infrastructure is vSphere' do
        let(:infrastructure) { Infrastructure.for('vsphere') }

        context 'when operating system is CentOS' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq([
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
                                                                 ])
          end
        end

        context 'when operating system is Ubuntu' do
          let(:operating_system) { OperatingSystem.for('ubuntu') }

          it 'has the correct stages' do
            expect(stage_collection.infrastructure_stages).to eq([
                                                                   :system_open_vm_tools,
                                                                   :system_parameters,
                                                                   :bosh_clean,
                                                                   :bosh_harden,
                                                                   :bosh_tripwire,
                                                                   :bosh_dpkg_list,
                                                                   :image_create,
                                                                   :image_install_grub,
                                                                   :image_vsphere_vmx,
                                                                   :image_vsphere_ovf,
                                                                   :image_vsphere_prepare_stemcell,
                                                                   :stemcell
                                                                 ])
          end
        end
      end
    end
  end
end
