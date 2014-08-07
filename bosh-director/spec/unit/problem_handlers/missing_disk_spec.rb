require 'spec_helper'

describe Bosh::Director::ProblemHandlers::MissingDisk do
  let(:handler) { described_class.new(disk.id, {}) }
  before { allow(handler).to receive(:cloud).and_return(cloud) }
  before { allow(handler).to receive(:agent_client).with(instance.vm).and_return(agent_client) }

  let(:cloud) { instance_double('Bosh::Cloud', detach_disk: nil) }
  before { allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud) }

  let(:agent_client) { instance_double('Bosh::Director::AgentClient', unmount_disk: nil) }

  let(:instance) do
    Bosh::Director::Models::Instance.
      make(job: 'mysql_node', index: 3, vm_id: vm.id)
  end

  let(:vm) do
    Bosh::Director::Models::Vm.make(cid: 'vm-cid')
  end

  let!(:disk) do
    Bosh::Director::Models::PersistentDisk.
      make(disk_cid: 'disk-cid', instance_id: instance.id,
      size: 300, active: false)
  end

  it 'registers under missing_disk type' do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:missing_disk, disk.id, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::MissingDisk)
  end

  it 'has well-formed description' do
    expect(handler.description).to eq("Disk `disk-cid' (mysql_node/3, 300M) is missing")
  end

  describe 'resolutions' do
    describe 'delete_disk_reference' do
      before do
        Bosh::Director::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snapshot-cid')
        allow(agent_client).to receive(:list_disk).and_return({})
        allow(cloud).to receive(:delete_snapshot)
      end

      it 'ignores the error if disk is not attached' do
        handler.apply_resolution(:delete_disk_reference)
        expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
      end

      context 'when agent responds to list_disk' do
        context 'when disk is in the list of agent disks' do
          before do
            allow(agent_client).to receive(:list_disk).and_return(['disk-cid'])
          end

          it 'deactivates, unmounts, detaches, deletes snapshots and deletes disk from database' do
            expect(agent_client).to receive(:unmount_disk) do
              db_disk = Bosh::Director::Models::PersistentDisk[disk.id]
              expect(db_disk.active).to be(false)
            end.ordered

            expect(cloud).to receive(:detach_disk).with('vm-cid', 'disk-cid').ordered
            expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered

            handler.apply_resolution(:delete_disk_reference)

            expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
            expect(Bosh::Director::Models::Snapshot.all).to be_empty
            expect(instance.persistent_disk_cid).to be_nil
          end

          context 'when unmount_disk fails with error' do
            before do
              allow(agent_client).to receive(:unmount_disk).and_raise(
                Bosh::Director::RpcRemoteException.new('something bad happened')
              )
            end

            it 'raises that error' do
              expect(cloud).to_not receive(:detach_disk).with('vm-cid', 'disk-cid').ordered
              expect(cloud).to_not receive(:delete_snapshot).with('snapshot-cid').ordered

              expect {
                handler.apply_resolution(:delete_disk_reference)
              }.to raise_error(Bosh::Director::ProblemHandlerError)

              expect(Bosh::Director::Models::PersistentDisk[disk.id]).to_not be_nil
              expect(Bosh::Director::Models::Snapshot.all).to_not be_empty
            end
          end
        end

        context 'when disk is not in the list of agent disks' do
          before do
            allow(agent_client).to receive(:list_disk).and_return([])
          end

          it 'deactivates, detaches, deletes snapshots and deletes disk from database' do
            expect(agent_client).to_not receive(:unmount_disk)

            expect(cloud).to receive(:detach_disk).with('vm-cid', 'disk-cid') do
              db_disk = Bosh::Director::Models::PersistentDisk[disk.id]
              expect(db_disk.active).to be(false)
            end.ordered

            expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered

            handler.apply_resolution(:delete_disk_reference)

            expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
            expect(Bosh::Director::Models::Snapshot.all).to be_empty
          end
        end
      end

      context 'when agent does not responds to list_disk' do
        before do
          allow(agent_client).to receive(:list_disk).and_raise(Bosh::Director::RpcTimeout)
        end

        it 'does not detach, delete snapshots, delete disk' do
          expect(agent_client).to_not receive(:unmount_disk)
          expect(cloud).to_not receive(:detach_disk)
          expect(cloud).to_not receive(:delete_snapshot).with('snapshot-cid')

          expect {
            handler.apply_resolution(:delete_disk_reference)
          }.to raise_error(Bosh::Director::ProblemHandlerError)

          expect(Bosh::Director::Models::PersistentDisk[disk.id]).to_not be_nil
          expect(Bosh::Director::Models::Snapshot.all).to_not be_empty
        end
      end
    end
  end
end
