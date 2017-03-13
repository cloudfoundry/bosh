require 'spec_helper'
require 'logger'
require 'timecop'

describe Bosh::Director::MetadataUpdater do
  subject(:metadata_updater) { described_class.new(director_metadata, logger) }
  let(:director_metadata) { {} }
  let(:instance) { BD::Models::Instance.make(deployment: deployment, vm_cid: 'fake-vm-cid', uuid: 'some_instance_id', job: 'job-value', index: 12345, availability_zone: 'az1') }
  let(:deployment) { BD::Models::Deployment.make(name: 'deployment-value') }
  let(:cloud) { Bosh::Director::Config.cloud }

  describe '.build' do
    it 'returns metadata updater' do
      logger = double('logger')
      allow(Bosh::Director::Config).to receive_messages(name: 'fake-director-name', logger: logger)

      updater = instance_double('Bosh::Director::MetadataUpdater')
      expect(described_class).to receive(:new).with(
          {'director' => 'fake-director-name'}, logger).and_return(updater)

      expect(described_class.build).to eq(updater)
    end
  end

  describe '#update_vm_metadata' do
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }

    before do
      allow(Bosh::Director::CloudFactory).to receive(:new).and_return(cloud_factory)
      expect(cloud_factory).to receive(:for_availability_zone!).with(instance.availability_zone).and_return(cloud)
    end

    context 'when CPI supports setting vm metadata' do
      it 'updates vm metadata with provided metadata' do
        expected_vm_metadata = {'fake-custom-key1' => 'fake-custom-value1'}
        expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
        metadata_updater.update_vm_metadata(instance, expected_vm_metadata)
      end

      it 'updates vm metadata with director metadata' do
        expected_vm_metadata = {'fake-director-key1' => 'fake-director-value1'}
        director_metadata.merge!(expected_vm_metadata)
        expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
        metadata_updater.update_vm_metadata(instance, {})
      end

      it 'updates vm metadata with creation time' do
        Timecop.freeze do
          expected_vm_metadata = {'created_at' => Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')}
          expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
          metadata_updater.update_vm_metadata(instance, {})
        end
      end

      it 'does not mutate passed metadata' do
        passed_in_metadata = {}
        metadata_updater.update_vm_metadata(instance, passed_in_metadata)
        expect(passed_in_metadata).to eq({})
      end

      it 'updates vm metadata with deployment specific metadata' do
        expect(cloud).to receive(:set_vm_metadata)
          .with('fake-vm-cid', hash_including('deployment' => 'deployment-value'))
        metadata_updater.update_vm_metadata(instance, {})
      end

      it 'updates vm metadata with instance specific metadata' do
        expected_vm_metadata = {
          'id' => 'some_instance_id',
          'job' => 'job-value',
          'index' => '12345',
          'name' => 'job-value/some_instance_id',
        }
        expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including(expected_vm_metadata))
        metadata_updater.update_vm_metadata(instance, {})
      end

      it 'turns job index metadata into a string' do
        expect(cloud).to receive(:set_vm_metadata).with('fake-vm-cid', hash_including('index' => '12345'))
        metadata_updater.update_vm_metadata(instance, {})
      end
    end

    context 'when CPI does not support setting vm metadata' do
      it 'does not mutate passed metadata' do
        passed_in_metadata = {}
        metadata_updater.update_vm_metadata(instance, passed_in_metadata)
        expect(passed_in_metadata).to eq({})
      end
    end

    context 'when set_vm_metadata is not part of CPI' do
      before { allow(cloud).to receive(:respond_to?).with(:set_vm_metadata).and_return(false) }

      it 'does not set vm metadata' do
        expect(cloud).not_to receive(:set_vm_metadata)
        metadata_updater.update_vm_metadata(instance, {})
      end
    end

    context 'when set_vm_metadata raises not implemented error' do
      before { allow(cloud).to receive(:set_vm_metadata).and_raise(Bosh::Clouds::NotImplemented) }

      it 'does not propagate raised error' do
        expect { metadata_updater.update_vm_metadata(instance, {}) }.to_not raise_error
      end
    end
  end

  describe '#update_disk_metadata' do
    let(:disk) { BD::Models::PersistentDisk.make(instance_id: 'fake-vm-cid', disk_cid: 'fake-disk-cid')}
    before do
      instance.add_persistent_disk(disk) if disk
    end

    context 'when CPI supports setting disk metadata' do
      it 'adds director metadata' do
        expected_disk_metadata = {'fake-director-key1' => 'fake-director-value1'}
        director_metadata.merge!(expected_disk_metadata)
        expect(cloud).to receive(:set_disk_metadata).with('fake-disk-cid', hash_including(expected_disk_metadata))
        metadata_updater.update_disk_metadata(cloud, disk, {})
      end

      it 'adds deployment specific metadata' do
        expect(cloud).to receive(:set_disk_metadata).with('fake-disk-cid',
          hash_including({'deployment' => 'deployment-value'}))
        metadata_updater.update_disk_metadata(cloud, disk, {})
      end

      it 'adds instance specific metadata' do
        expected_disk_metadata = {
          'instance_id' => 'some_instance_id',
          'job' => 'job-value',
          'instance_index' => '12345',
          'instance_name' => 'job-value/some_instance_id',
        }
        expect(cloud).to receive(:set_disk_metadata).with('fake-disk-cid', hash_including(expected_disk_metadata))
        metadata_updater.update_disk_metadata(cloud, disk, {})
      end

      it 'turns job index metadata into a string' do
        expect(cloud).to receive(:set_disk_metadata).with('fake-disk-cid', hash_including({'instance_index' => '12345'}))
        metadata_updater.update_disk_metadata(cloud, disk, {})
      end

      it 'updates disk metadata with provided metadata' do
        expected_disk_metadata = {'fake-custom-key1' => 'fake-custom-value1'}
        expect(cloud).to receive(:set_disk_metadata).with('fake-disk-cid', hash_including(expected_disk_metadata))
        metadata_updater.update_disk_metadata(cloud, disk, expected_disk_metadata)
      end

      it 'updates disk metadata with attachment time' do
        Timecop.freeze do
          expected_disk_metadata = {'attached_at' => Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')}
          expect(cloud).to receive(:set_disk_metadata).with('fake-disk-cid', hash_including(expected_disk_metadata))
          metadata_updater.update_disk_metadata(cloud, disk, {})
        end
      end
    end

    context 'when set_disk_metadata is not part of CPI' do
      before { allow(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(false) }

      it 'does not set disk metadata' do
        expect(cloud).not_to receive(:set_disk_metadata)
        metadata_updater.update_disk_metadata(cloud, disk, {})
      end
    end

    context 'when set_disk_metadata raises not implemented error' do
      before { allow(cloud).to receive(:set_disk_metadata).and_raise(Bosh::Clouds::NotImplemented) }

      it 'does not propagate raised error' do
        expect { metadata_updater.update_disk_metadata(cloud, disk, {}) }.to_not raise_error
      end
    end
  end
end
