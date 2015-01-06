require 'spec_helper'
require 'logger'

describe Bosh::Director::VmMetadataUpdater do
  describe '.build' do
    it 'returns metadata updater' do
      cloud = instance_double('Bosh::Cloud')
      logger = double('logger')
      allow(Bosh::Director::Config).to receive_messages(
        cloud: cloud, name: 'fake-director-name', logger: logger)

      updater = instance_double('Bosh::Director::VmMetadataUpdater')
      expect(described_class).to receive(:new).with(
        cloud, {director: 'fake-director-name'}, logger).and_return(updater)

      expect(described_class.build).to eq(updater)
    end
  end

  describe '#update' do
    subject(:vm_metadata_updater) { described_class.new(cloud, director_metadata, logger) }
    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:director_metadata) { {} }

    let(:vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid', deployment: deployment, instance: nil) }
    let(:deployment) { instance_double('Bosh::Director::Models::Deployment', name: 'deployment-value') }

    context 'when CPI supports setting vm metadata' do
      it 'updates vm metadata with provided metadata' do
        expected_vm_metadata = { 'fake-custom-key1' => 'fake-custom-value1' }
        expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
        vm_metadata_updater.update(vm, expected_vm_metadata)
      end

      it 'updates vm metadata with director metadata' do
        expected_vm_metadata = { 'fake-director-key1' => 'fake-director-value1' }
        director_metadata.merge!(expected_vm_metadata)
        expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
        vm_metadata_updater.update(vm, {})
      end

      it 'does not mutate passed metadata' do
        passed_in_metadata = {}
        vm_metadata_updater.update(vm, passed_in_metadata)
        expect(passed_in_metadata).to eq({})
      end

      context 'when vm has an instance' do
        before { allow(vm).to receive_messages(instance: instance) }
        let(:instance) { instance_double('Bosh::Director::Models::Instance', job: 'job-value', index: 'index-value') }

        it 'updates vm metadata with deployment specific metadata' do
          expect(cloud).to receive(:set_vm_metadata)
            .with('fake-vm-cid', hash_including(deployment: 'deployment-value'))
          vm_metadata_updater.update(vm, {})
        end

        it 'updates vm metadata with instance specific metadata' do
          expected_vm_metadata = {
            job: 'job-value',
            index: 'index-value',
          }
          expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
          vm_metadata_updater.update(vm, {})
        end

        it 'turns job index metadata into a string' do
          allow(instance).to receive_messages(index: 12345)
          expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(index: '12345'))
          vm_metadata_updater.update(vm, {})
        end
      end

      context 'when the vm does not have an instance' do
        before { allow(vm).to receive_messages(instance: nil) }

        it 'updates vm metadata with deployment specific metadata' do
          expect(cloud).to receive(:set_vm_metadata)
            .with('fake-vm-cid', hash_including(deployment: 'deployment-value'))
          vm_metadata_updater.update(vm, {})
        end

        it 'updates vm metadata without including instance specific metadata' do
          expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_excluding(:job, :index))
          vm_metadata_updater.update(vm, {})
        end
      end
    end

    context 'when set_vm_metadata is not part of CPI' do
      before { allow(cloud).to receive(:respond_to?).with(:set_vm_metadata).and_return(false) }

      it 'does not set vm metadata' do
        expect(cloud).not_to receive(:set_vm_metadata)
        vm_metadata_updater.update(vm, {})
      end
    end

    context 'when set_vm_metadata raises not implemented error' do
      before { allow(cloud).to receive(:set_vm_metadata).and_raise(Bosh::Clouds::NotImplemented) }

      it 'does not propagate raised error' do
        expect { vm_metadata_updater.update(vm, {}) }.to_not raise_error
      end
    end
  end
end
