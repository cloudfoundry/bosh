require 'spec_helper'
require 'bosh/stemcell/stage_collection'

module Bosh::Stemcell
  describe StageCollection do
    it { should be_a(Module) }

    describe '.for' do
      it 'returns the correct stage collection' do
        expect(StageCollection.for('stemcell-aws-xen-ubuntu')).to be_a(StageCollection::AwsUbuntu)
        expect(StageCollection.for('stemcell-openstack-kvm-ubuntu')).to be_a(StageCollection::OpenstackUbuntu)
        expect(StageCollection.for('stemcell-vsphere-esxi-centos')).to be_a(StageCollection::VsphereCentos)
        expect(StageCollection.for('stemcell-vsphere-esxi-ubuntu')).to be_a(StageCollection::VsphereUbuntu)
      end

      it 'raises for unknown stage collection name' do
        expect {
          StageCollection.for('BAD_STAGE_COLLECTION_NAME')
        }.to raise_error(ArgumentError, /invalid stage collection: BAD_STAGE_COLLECTION_NAME/)
      end
    end
  end

  describe StageCollection::AwsUbuntu do
    subject(:aws_ubuntu) { described_class.new }

    it { should be_a(StageCollection::Base) }

    it 'has the correct stages' do
      expect(aws_ubuntu.stages).to eq([
                                        :base_debootstrap,
                                        :base_apt,
                                        :bosh_users,
                                        :bosh_debs,
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

  describe StageCollection::OpenstackUbuntu do
    subject(:openstack_ubuntu) { described_class.new }

    it { should be_a(StageCollection::Base) }

    it 'has the correct stages' do
      expect(openstack_ubuntu.stages).to eq([
                                              :base_debootstrap,
                                              :base_apt,
                                              :bosh_users,
                                              :bosh_debs,
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

  describe StageCollection::VsphereCentos do
    subject(:vsphere_centos) { described_class.new }

    it { should be_a(StageCollection::Base) }

    it 'has the correct stages' do
      expect(vsphere_centos.stages).to eq([
                                            :base_centos,
                                            :base_yum,
                                            :bosh_users,
                                            #:bosh_monit,
                                            #:bosh_ruby,
                                            #:bosh_agent,
                                            #:bosh_sysstat,
                                            #:bosh_sysctl,
                                            #:bosh_ntpdate,
                                            #:bosh_sudoers,
                                            #:bosh_micro,
                                            :system_grub,
                                            #:system_kernel,
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

  describe StageCollection::VsphereUbuntu do
    subject(:vsphere_ubuntu) { described_class.new }

    it { should be_a(StageCollection::Base) }

    it 'has the correct stages' do
      expect(vsphere_ubuntu.stages).to eq([
                                            :base_debootstrap,
                                            :base_apt,
                                            :bosh_users,
                                            :bosh_debs,
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
