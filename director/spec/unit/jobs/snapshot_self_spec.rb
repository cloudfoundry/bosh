require 'spec_helper'

describe Bosh::Director::Jobs::SnapshotSelf do
  let(:cloud) { instance_double('Bosh::Cloud') }
  let(:director_uuid) { 'cafebabe' }
  let(:director_name) { 'Test Director' }
  let(:enable_snapshots) { true }
  let(:subject) do
    described_class.new(cloud: cloud,
                        director_uuid: director_uuid,
                        director_name: director_name,
                        enable_snapshots: enable_snapshots)
  end

  describe 'Resque job class expectations' do
    let(:job_type) { :snapshot_self }
    it_behaves_like 'a Resque job'
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

    it 'should snapshot all of my disks' do
      cloud.should_receive(:current_vm_id).and_return(vm_id)
      cloud.should_receive(:get_disks).with(vm_id).and_return(disks)
      cloud.should_receive(:snapshot_disk).with(disks[0], metadata)
      cloud.should_receive(:snapshot_disk).with(disks[1], metadata)
      subject.perform
    end

    it 'returns a message containing the volume ids snapshotted' do
      cloud.stub(current_vm_id: vm_id, get_disks: disks, snapshot_disk: nil)
      expect(subject.perform).to include('vol-id1, vol-id2')
    end

    context 'when snapshotting is disabled' do
      let(:enable_snapshots) { false }

      it 'does nothing' do
        cloud.should_not_receive(:current_vm_id)
        cloud.should_not_receive(:get_disks)
        cloud.should_not_receive(:snapshot_disk)
        subject.perform
      end
    end

    context 'with a CPI that does not support snapshots' do
      it 'does nothing' do
        cloud.should_receive(:current_vm_id).and_raise(Bosh::Clouds::NotImplemented)

        expect { subject.perform }.to_not raise_error
      end
    end
  end
end