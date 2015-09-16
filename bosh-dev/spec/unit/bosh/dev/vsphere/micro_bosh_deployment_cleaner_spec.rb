require 'spec_helper'
require 'ruby_vim_sdk'
require 'bosh/dev/vsphere/micro_bosh_deployment_cleaner'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'

module Bosh::Dev::VSphere
  describe MicroBoshDeploymentCleaner do
    describe '#clean' do
      subject(:cleaner) { described_class.new(manifest) }
      let(:manifest) { instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest') }

      before { allow(VSphereCloud::Cloud).to receive(:new).with('fake config').and_return(cloud) }
      let(:cloud) { instance_double('VSphereCloud::Cloud', client: client) }
      let(:client) { double('fake client') }

      before { allow(manifest).to receive(:to_h).and_return(config) }
      let(:config) { { 'cloud' => { 'properties' => 'fake config' } } }

      before { allow(Bosh::Clouds::Config).to receive(:db) }
      let(:sequel_klass) { class_double('Sequel::Model').as_stubbed_const }

      context 'when get_vms returns vms' do
        before { allow(cloud).to receive_messages(get_vms: [vm1, vm2]) }
        let(:vm1) { instance_double(VSphereCloud::Resources::VM, cid: 'fake-vm-1') }
        let(:vm2) { instance_double(VSphereCloud::Resources::VM, cid: 'fake-vm-2') }

        it 'kills vms that are in subfolders of that folder' do
          expect(vm1).to receive(:power_off).ordered
          expect(vm1).to receive(:wait_until_off).with(15).ordered
          expect(vm1).to receive(:delete).ordered

          expect(vm2).to receive(:power_off).ordered
          expect(vm2).to receive(:wait_until_off).with(15).ordered
          expect(vm2).to receive(:delete).ordered

          cleaner.clean
        end
      end

      context 'when no vms are found in the folder' do
        it 'finishes without complaining' do
          allow(cloud).to receive_messages(get_vms: [])
          cleaner.clean
        end
      end

      context 'when destruction fails' do
        before { allow(cloud).to receive_messages(get_vms: [vm1]) }
        let(:vm1) { instance_double(VSphereCloud::Resources::VM, cid: 'fake-vm-1') }

        it 'logs a failure but doesn\'t stop' do
          allow(vm1).to receive(:power_off).and_raise
          cleaner.clean

          expect(log_string).to include("Destruction of #{vm1.inspect} failed with RuntimeError: RuntimeError. Manual cleanup may be required. Continuing and hoping for the best...")
        end
      end
    end
  end
end
