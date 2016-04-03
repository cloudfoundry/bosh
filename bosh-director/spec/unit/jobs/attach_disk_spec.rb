require 'spec_helper'

module Bosh::Director
  describe Jobs::AttachDisk do

    let(:deployment_name) { 'fake_deployment_name' }
    let(:disk_cid) { 'fake_disk_cid' }
    let(:job_name) { 'job_name' }
    let(:instance_id) { 'fake_instance_id' }
    let(:event_manager) {Api::EventManager.new(true)}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager)}

    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }

      it 'enqueues an AttachDisk job' do
        expect(job_queue).to receive(:enqueue).with(
          'fake-username',
          Jobs::AttachDisk,
          "attach disk 'fake_disk_cid' to 'job_name/fake_instance_id'",
          [deployment_name, job_name, instance_id, disk_cid], deployment_name)
        Jobs::AttachDisk.enqueue('fake-username', deployment_name, job_name, instance_id, disk_cid, job_queue)
      end
    end

    let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, instance_id, disk_cid) }

    describe '#perform' do
      let!(:instance_model) { Models::Instance.make(uuid: instance_id, job: job_name, vm_cid: vm_cid, state: instance_state) }
      let!(:deployment_model) do
        deployment_model = Models::Deployment.make(name: deployment_name)
        deployment_model.add_instance(instance_model)
        deployment_model
      end

      before {
        allow(Config).to receive(:cloud)
        allow(Config).to receive(:current_job).and_return(update_job)
      }

      context 'when the instance is stopped hard' do
        let(:vm_cid) { nil }
        let(:instance_state) {'detached'}

        let!(:original_disk) do
          Models::PersistentDisk.make(
            disk_cid: 'original-disk-cid',
            instance_id: instance_model.id,
            active: true,
            size: 50)
        end

        it 'attaches the disk' do
          attach_disk_job.perform
          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.count).to eq(1)
          expect(active_disks.first.disk_cid).to eq(disk_cid)
        end

        it 'sets the disk size to 1 so it is migrated to the desired size next deploy' do
          attach_disk_job.perform
          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.first.size).to eq(1)
        end

        it 'marks the pre existing active persistent disk as inactive and orphans it' do
          attach_disk_job.perform
          expect(instance_model.persistent_disks).to_not include(original_disk)
          original_persistent_disk = Models::PersistentDisk[disk_cid: 'original-disk-cid']
          expect(original_persistent_disk).to be(nil)

          orphaned_original_disk = Models::OrphanDisk[disk_cid: 'original-disk-cid']
          expect(orphaned_original_disk).to_not be(nil)
        end

        it 'returns a message' do
          expect(attach_disk_job.perform).to eq("attached disk 'fake_disk_cid' to 'job_name/fake_instance_id' in deployment 'fake_deployment_name'")
        end

        context 'when the instance with the given instance id cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, 'bogus', disk_cid) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'job_name/bogus' in deployment 'fake_deployment_name' was not found")
          end
        end

        context 'when the instance with the given job name cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, 'bogus', instance_id, disk_cid) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'bogus/fake_instance_id' in deployment 'fake_deployment_name' was not found")
          end
        end

        context 'when the instance with the given deployment name cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new('bogus', job_name, instance_id, disk_cid) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'job_name/fake_instance_id' in deployment 'bogus' was not found")
          end
        end

        context 'when the instance is not stopped --hard a.k.a. detached' do
          before do
            instance_model.update(state: 'started')
          end
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskInvalidInstanceState,
                                                              "Instance 'job_name/fake_instance_id' in deployment 'fake_deployment_name' must be in 'bosh stopped' state")
          end
        end

        context 'when orphaned disk is attached' do
          let!(:original_disk) do
            Models::PersistentDisk.make(
                disk_cid: 'original-disk-cid',
                instance_id: instance_model.id,
                active: true,
                size: 50)
          end

          let!(:orphan_disk) do
            Models::OrphanDisk.make(
                disk_cid: 'orphan-disk-cid',
                instance_name: 'fake-instance',
                availability_zone: 'o-zone',
                deployment_name: deployment_name,
                cloud_properties: {})
          end

          let!(:snapshot) do
            Models::Snapshot.make(
                persistent_disk: original_disk,
                clean: true,
                snapshot_cid: original_disk.disk_cid)
          end

          let!(:orphan_disk_snapshot) do
            Models::OrphanSnapshot.make(
                orphan_disk: orphan_disk,
                clean: false,
                snapshot_cid: orphan_disk.disk_cid,
                snapshot_created_at: Date.today)
          end

          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, instance_id, orphan_disk.disk_cid) }

          before do
            attach_disk_job.perform
          end

          it 'attaches the orphaned disk' do
            expect(Models::OrphanDisk.where(disk_cid: orphan_disk.disk_cid).count).to eq(0)
            expect(Models::PersistentDisk.where(disk_cid: orphan_disk.disk_cid).count).to eq(1)
          end

          it 'attaches the orphaned snapshots for the orphan disk' do
            expect(Models::OrphanSnapshot.where(snapshot_cid: orphan_disk.disk_cid).count).to eq(0)
            expect(Models::Snapshot.where(snapshot_cid: orphan_disk.disk_cid).count).to eq(1)
          end

          it 'orphans the existing persistent disk' do
            expect(Models::PersistentDisk.where(disk_cid: original_disk.disk_cid).count).to eq(0)
            expect(Models::OrphanDisk.where(disk_cid: original_disk.disk_cid).count).to eq(1)
          end

          it 'orphans the existing disk snapshots' do
            expect(Models::OrphanSnapshot.where(snapshot_cid: original_disk.disk_cid).count).to eq(1)
            expect(Models::Snapshot.where(snapshot_cid: original_disk.disk_cid).count).to eq(0)
          end

          it 'unorphanes any snapshots for the orphan disk' do
            expect(Models::Snapshot.where(snapshot_cid: orphan_disk.disk_cid).count).to eq(1)
          end

          it 'creates orphan disks from the existing persistent disk properties' do
            current_orphan_disk = Models::OrphanDisk.first

            expect(current_orphan_disk.disk_cid).to eq(original_disk.disk_cid)
            expect(current_orphan_disk.size).to eq(original_disk.size)
            expect(current_orphan_disk.availability_zone).to eq(original_disk.instance.availability_zone)
            expect(current_orphan_disk.deployment_name).to eq(original_disk.instance.deployment.name)
            expect(current_orphan_disk.instance_name).to eq(original_disk.instance.name)
            expect(current_orphan_disk.cloud_properties).to eq(original_disk.cloud_properties)
          end

          it 'creates orphan snapshots from existing snapshots' do
            current_orphan_snapshot = Models::OrphanSnapshot.first
            current_orphan_disk = Models::OrphanDisk.first

            expect(current_orphan_snapshot.orphan_disk).to eq(current_orphan_disk)
            expect(current_orphan_snapshot.snapshot_cid).to eq(snapshot.snapshot_cid)
            expect(current_orphan_snapshot.clean).to eq(snapshot.clean)
            expect(current_orphan_snapshot.snapshot_created_at).to eq(snapshot.created_at)
          end

          it 'unorphans using orphan disk properties' do
            current_disk = Models::PersistentDisk.first

            expect(current_disk.disk_cid).to eq(orphan_disk.disk_cid)
            expect(current_disk.size).to eq(orphan_disk.size)
            expect(current_disk.active).to eq(true)
            expect(current_disk.cloud_properties).to eq(orphan_disk.cloud_properties)
          end

          it 'creates unorphan snapshots using orphan snapshots' do
            current_snapshot = Models::Snapshot.first
            current_disk = Models::PersistentDisk.first

            expect(current_snapshot.persistent_disk).to eq(current_disk)
            expect(current_snapshot.snapshot_cid).to eq(orphan_disk_snapshot.snapshot_cid)
            expect(current_snapshot.clean).to eq(orphan_disk_snapshot.clean)
          end
        end
      end

      context 'when the instance is stopped soft' do
        let(:vm_cid) { nil }

        let(:instance_state) {'stopped'}

        let!(:original_disk) do
          Models::PersistentDisk.make(
              disk_cid: 'original-disk-cid',
              instance_id: instance_model.id,
              active: true,
              size: 50)
        end

        let(:disk_manager) { instance_double(DiskManager)}

        before {
          allow(DiskManager).to receive(:new).and_return(disk_manager)
          allow(disk_manager).to receive(:detach_disk)
          allow(disk_manager).to receive(:unmount_disk)
          allow(disk_manager).to receive(:orphan_disk)
          allow(disk_manager).to receive(:attach_disk)
        }

        it 'attaches the new disk' do
          expect(disk_manager).to receive(:attach_disk)
          attach_disk_job.perform

          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.count).to eq(1)
          expect(active_disks.first.disk_cid).to eq(disk_cid)
        end

        it 'orphans and unmounts the previous disk' do
          expect(disk_manager).to receive(:detach_disk).with(instance_model, original_disk)
          expect(disk_manager).to receive(:unmount_disk).with(instance_model, original_disk)
          expect(disk_manager).to receive(:orphan_disk).with(original_disk)
          attach_disk_job.perform
        end
      end

      context 'when the job does not declare persistent disk' do
        let(:vm_cid) { nil }

        let(:instance_state) {'stopped'}
        
        let(:original_disk) { nil }

        let(:disk_manager) { instance_double(DiskManager)}

        before {
          allow(DiskManager).to receive(:new).and_return(disk_manager)
          allow(disk_manager).to receive(:detach_disk)
          allow(disk_manager).to receive(:unmount_disk)
          allow(disk_manager).to receive(:orphan_disk)
          allow(disk_manager).to receive(:attach_disk)
        }

        it 'attaches the new disk' do
          expect(disk_manager).to receive(:attach_disk)
          attach_disk_job.perform

          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.count).to eq(1)
          expect(active_disks.first.disk_cid).to eq(disk_cid)
        end

        it 'performs no action for previous disk' do
          expect(disk_manager).to_not receive(:detach_disk).with(instance_model, original_disk)
          expect(disk_manager).to_not receive(:unmount_disk).with(instance_model, original_disk)
          expect(disk_manager).to_not receive(:orphan_disk).with(original_disk)
        end
      end
    end
  end
end
