require 'spec_helper'
require 'bosh/dev/vsphere/micro_bosh_deployment_cleaner'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'
require 'ruby_vim_sdk'

module Bosh::Dev::VSphere
  describe MicroBoshDeploymentCleaner do
    describe '#clean' do
      let(:folder_object) { double('fake folder object') }
      let(:folder) { instance_double('VSphereCloud::Resources::Folder', mob: folder_object) }
      let(:logger) { instance_double('Logger', info: nil) }
      let(:cloud) { instance_double('VSphereCloud::Cloud', client: client) }
      let(:client) { double('fake client') }
      let(:sequel_klass) { class_double('Sequel::Model').as_stubbed_const }
      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil, name: 'fake vm 1') }
      let(:vm2) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil, name: 'fake vm 2') }

      let(:config) { { 'cloud' => { 'properties' => 'fake config' } } }
      let(:manifest) { instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest') }

      before do
        VSphereCloud::Cloud.stub(:new).with('fake config').and_return(cloud)
        Logger.stub(new: logger)
        Bosh::Clouds::Config.stub(:db)

        manifest.stub(:to_h).and_return(config)
      end

      subject(:micro_bosh_deployment_cleaner) { described_class.new(manifest) }

      context 'when get_vms returns vms' do
        it 'kills vms that are in subfolders of that folder' do
          client.should_receive(:power_off_vm).with(vm)
          client.should_receive(:power_off_vm).with(vm2)

          cloud.should_receive(:wait_until_off).with(vm, 15)
          cloud.should_receive(:wait_until_off).with(vm2, 15)

          vm.should_receive(:destroy)
          vm2.should_receive(:destroy)

          cloud.stub(get_vms: [vm, vm2])

          micro_bosh_deployment_cleaner.clean
        end
      end

      context 'when no vms are found in the folder' do
        it 'finishes without complaining' do
          cloud.stub(get_vms: [])
          micro_bosh_deployment_cleaner.clean
        end
      end

      context 'when destruction fails' do
        it 'logs a failure but doesn\'t stop' do
          client.stub(:power_off_vm).and_raise

          cloud.stub(get_vms: [vm])

          logger.should_receive(:info).with("Destruction of #{vm.inspect} failed, continuing")

          micro_bosh_deployment_cleaner.clean
        end
      end
    end
  end
end
