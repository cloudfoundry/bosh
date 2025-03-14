require 'spec_helper'

describe Bosh::Director::Jobs::SnapshotSelf do
  let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
  let(:director_uuid) { 'cafebabe' }
  let(:director_name) { 'Test Director' }
  let(:enable_snapshots) { true }
  let(:subject) do
    described_class.new(cloud: cloud,
                        director_uuid: director_uuid,
                        director_name: director_name,
                        enable_snapshots: enable_snapshots)
  end

  describe 'DJ job class expectations' do
    let(:job_type) { :snapshot_self }
    let(:queue) { :normal }
    it_behaves_like 'a DelayedJob job'
  end

  describe '#perform' do
    let(:vm_id) { 'id-foo' }
    let(:disks) { ['vol-id1', 'vol-id2'] }
    let(:metadata) do
      {
        deployment: 'self',
        job: 'director',
        index: 0,
        director_name: director_name,
        director_uuid: director_uuid,
        agent_id: 'self',
        instance_id: vm_id
      }
    end

    before do
      allow(cloud).to receive(:current_vm_id).and_return(vm_id)
      allow(cloud).to receive(:get_disks).with(vm_id).and_return(disks)
      allow(cloud).to receive(:snapshot_disk).with(disks[0], metadata)
      allow(cloud).to receive(:snapshot_disk).with(disks[1], metadata)
    end

    it 'should snapshot all of my disks' do
      expect(cloud).to receive(:current_vm_id).and_return(vm_id)
      expect(cloud).to receive(:get_disks).with(vm_id).and_return(disks)
      expect(cloud).to receive(:snapshot_disk).with(disks[0], metadata)
      expect(cloud).to receive(:snapshot_disk).with(disks[1], metadata)
      subject.perform
    end

    it 'returns a message containing the volume ids snapshotted' do
      allow(cloud).to receive_messages(current_vm_id: vm_id, get_disks: disks, snapshot_disk: nil)
      expect(subject.perform).to include('vol-id1, vol-id2')
    end

    context 'when snapshotting is disabled' do
      let(:enable_snapshots) { false }

      it 'does nothing' do
        expect(cloud).not_to receive(:current_vm_id)
        expect(cloud).not_to receive(:get_disks)
        expect(cloud).not_to receive(:snapshot_disk)
        subject.perform
      end
    end

    context 'with a CPI that does not support snapshots' do
      it 'does nothing' do
        expect(cloud).to receive(:current_vm_id).and_raise(Bosh::Clouds::NotImplemented)

        expect { subject.perform }.to_not raise_error
      end
    end

    context 'when no cloud provided' do
      let(:subject) do
        described_class.new(director_uuid: director_uuid,
                            director_name: director_name,
                            enable_snapshots: enable_snapshots)
      end

      it 'chooses default cloud' do
        expect(Bosh::Director::CloudFactory).to receive_message_chain(:create, :get).and_return(cloud)

        expect { subject.perform }.to_not raise_error
      end
    end
  end
end
