require 'spec_helper'
require 'ruby_vim_sdk'
require 'bosh/dev/vsphere/micro_bosh_deployment_cleaner'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'

module Bosh::Dev::VSphere
  describe MicroBoshDeploymentCleaner do
    describe '#clean' do
      subject(:cleaner) { described_class.new(manifest) }
      let(:manifest) { instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest') }

      before { VSphereCloud::Cloud.stub(:new).with('fake config').and_return(cloud) }
      let(:cloud) { instance_double('VSphereCloud::Cloud', client: client) }
      let(:client) { double('fake client') }

      before { manifest.stub(:to_h).and_return(config) }
      let(:config) { { 'cloud' => { 'properties' => 'fake config' } } }

      before { Bosh::Clouds::Config.stub(:db) }
      let(:sequel_klass) { class_double('Sequel::Model').as_stubbed_const }

      before { Logger.stub(new: logger) }
      let(:logger) { instance_double('Logger', info: nil) }

      context 'when get_vms returns vms' do
        before { cloud.stub(get_vms: [vm1, vm2]) }
        let(:vm1) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil, name: 'fake vm 1') }
        let(:vm2) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil, name: 'fake vm 2') }

        it 'kills vms that are in subfolders of that folder' do
          client.should_receive(:power_off_vm).with(vm1).ordered
          cloud.should_receive(:wait_until_off).with(vm1, 15).ordered
          vm1.should_receive(:destroy).ordered

          client.should_receive(:power_off_vm).with(vm2).ordered
          cloud.should_receive(:wait_until_off).with(vm2, 15).ordered
          vm2.should_receive(:destroy).ordered

          cleaner.clean
        end
      end

      context 'when no vms are found in the folder' do
        it 'finishes without complaining' do
          cloud.stub(get_vms: [])
          cleaner.clean
        end
      end

      context 'when destruction fails' do
        before { cloud.stub(get_vms: [vm1]) }
        let(:vm1) { instance_double('VimSdk::Vim::VirtualMachine', destroy: nil, name: 'fake vm 1') }

        it 'logs a failure but doesn\'t stop' do
          client.stub(:power_off_vm).and_raise
          logger.should_receive(:info).with("Destruction of #{vm1.inspect} failed, continuing")
          cleaner.clean
        end
      end
    end
  end
end
