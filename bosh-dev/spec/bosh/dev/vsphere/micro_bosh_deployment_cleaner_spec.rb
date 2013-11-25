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
      let(:cloud) { instance_double('VSphereCloud::Cloud') }
      let(:sequel_klass) { class_double('Sequel::Model').as_stubbed_const }
      let(:vm) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil) }
      let(:vm2) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil) }

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
        it 'kills vms that are in that folder' do
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
          vm.stub(:destroy).and_raise

          cloud.stub(get_vms: [vm])

          logger.should_receive(:info).with("Destruction of #{vm.inspect} failed, continuing")

          micro_bosh_deployment_cleaner.clean
        end
      end
    end
  end
end
