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
        allow(cloud).to receive(:delete_disk)
      end

      def self.it_ignores_cloud_disk_errors
        it 'ignores the error if disk is not attached' do
          allow(cloud).to receive(:detach_disk).with('vm-cid', 'disk-cid') do
            raise Bosh::Clouds::DiskNotAttached.new(false)
          end

          expect {
            handler.apply_resolution(:delete_disk_reference)
          }.to_not raise_error
        end

        it 'ignores the error if disk is not found' do
          allow(cloud).to receive(:delete_disk).with('disk-cid') do
            raise Bosh::Clouds::DiskNotFound.new(false)
          end

          expect {
            handler.apply_resolution(:delete_disk_reference)
          }.to_not raise_error
        end
      end

      context 'when vm is present' do
        before do
          allow(cloud).to receive(:has_vm?).and_return(true)
        end

        context 'when agent responds to list_disk' do
          context 'when disk is in the list of agent disks' do
            before do
              allow(agent_client).to receive(:list_disk).and_return(['disk-cid'])
            end

            it_ignores_cloud_disk_errors

            it 'deactivates, unmounts, detaches, deletes snapshots, deletes disk from cloud, deletes disk reference' do
              expect(agent_client).to receive(:unmount_disk) do
                db_disk = Bosh::Director::Models::PersistentDisk[disk.id]
                expect(db_disk.active).to be(false)
              end.ordered

              expect(cloud).to receive(:detach_disk).with('vm-cid', 'disk-cid').ordered
              expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered
              expect(cloud).to receive(:delete_disk).ordered

              handler.apply_resolution(:delete_disk_reference)

              expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
              expect(Bosh::Director::Models::Snapshot.all).to be_empty
              expect(instance.persistent_disk_cid).to be_nil
            end

            context 'when unmount_disk fails with RpcTimeout error' do
              before do
                allow(agent_client).to receive(:unmount_disk).and_raise(
                  Bosh::Director::RpcTimeout.new('agent is unresponsive')
                )
              end

              it 'detaches disk, deletes snapshots, deletes disk, deletes disk reference' do
                expect(cloud).to receive(:detach_disk).with('vm-cid', 'disk-cid').ordered
                expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered
                expect(cloud).to receive(:delete_disk).ordered

                handler.apply_resolution(:delete_disk_reference)

                expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
                expect(Bosh::Director::Models::Snapshot.all).to be_empty
              end
            end

            context 'when unmount_disk fails with RpcRemoteException error' do
              before do
                allow(agent_client).to receive(:unmount_disk).and_raise(
                  Bosh::Director::RpcRemoteException.new('something bad happened')
                )
              end

              it 'raises the error' do
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

            it_ignores_cloud_disk_errors

            it 'deactivates, detaches, deletes snapshots, deletes disk from cloud, deletes disk reference' do
              expect(agent_client).to_not receive(:unmount_disk)

              expect(cloud).to receive(:detach_disk).with('vm-cid', 'disk-cid') do
                db_disk = Bosh::Director::Models::PersistentDisk[disk.id]
                expect(db_disk.active).to be(false)
              end.ordered

              expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered
              expect(cloud).to receive(:delete_disk).ordered

              handler.apply_resolution(:delete_disk_reference)

              expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
              expect(Bosh::Director::Models::Snapshot.all).to be_empty
            end
          end
        end

        context 'when agent does not respond to list_disk' do
          before do
            allow(agent_client).to receive(:list_disk).and_raise(Bosh::Director::RpcTimeout)
          end

          it_ignores_cloud_disk_errors

          it 'detaches disk, delete disk from cloud, deletes snapshots, deletes disk reference' do
            expect(agent_client).to_not receive(:unmount_disk)
            expect(cloud).to receive(:detach_disk).ordered
            expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered
            expect(cloud).to receive(:delete_disk).ordered

            handler.apply_resolution(:delete_disk_reference)

            expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
            expect(Bosh::Director::Models::Snapshot.all).to be_empty
          end
        end
      end

      context 'when vm is missing' do
        before do
          allow(cloud).to receive(:has_vm?).and_return(false)
        end

        it_ignores_cloud_disk_errors

        it 'deletes disk from cloud, deletes snapshots, deletes disk reference' do
          expect(agent_client).to_not receive(:unmount_disk)
          expect(cloud).to_not receive(:detach_disk)
          expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered
          expect(cloud).to receive(:delete_disk).ordered

          handler.apply_resolution(:delete_disk_reference)

          expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
          expect(Bosh::Director::Models::Snapshot.all).to be_empty
        end
      end

      context 'when vm is destroyed' do
        before do
          vm.instance.update(:vm => nil)
          vm.destroy
        end

        it 'deletes disk related info from cloud and database directly' do
          handler = described_class.new(disk.id, {})
          allow(handler).to receive(:cloud).and_return(cloud)

          expect(cloud).to receive(:delete_snapshot).with('snapshot-cid').ordered
          expect(cloud).to receive(:delete_disk).ordered

          expect {
            handler.apply_resolution(:delete_disk_reference)
          }.to_not raise_error

          expect(Bosh::Director::Models::PersistentDisk[disk.id]).to be_nil
          expect(Bosh::Director::Models::Snapshot.all).to be_empty
        end
      end
    end
  end
end
