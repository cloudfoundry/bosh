require 'spec_helper'

module Bosh::Director
  describe Jobs::AttachDisk do

    let(:manifest) do
      { 'tags' => { 'mytag' => 'myvalue' } }
    end
    let(:deployment) do
      deployment = FactoryBot.create(:models_deployment, name: deployment_name, manifest: YAML.dump(manifest))
      FactoryBot.create(:models_variable_set, deployment_id: deployment.id)
      deployment
    end
    let(:deployment_name) { 'fake_deployment_name' }
    let(:disk_cid) { 'fake_disk_cid' }
    let(:disk_properties) { '' }
    let(:job_name) { 'job_name' }
    let(:instance_id) { 'fake_instance_id' }
    let(:event_manager) {Api::EventManager.new(true)}
    let(:update_job) {instance_double(Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager)}
    let(:vm_cid) { 'test-cid' }

    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }

      it 'enqueues an AttachDisk job' do
        expect(job_queue).to receive(:enqueue).with(
          'fake-username',
          Jobs::AttachDisk,
          "attach disk 'fake_disk_cid' to 'job_name/fake_instance_id'",
          [deployment_name, job_name, instance_id, disk_cid, disk_properties], deployment)
        Jobs::AttachDisk.enqueue('fake-username', deployment, job_name, instance_id, disk_cid, disk_properties, job_queue)
      end
    end

    let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, instance_id, disk_cid, disk_properties) }

    describe '#perform' do
      let(:vm) { Models::Vm.make(cid: vm_cid, instance_id: instance_model.id) }
      let!(:instance_model) { FactoryBot.create(:models_instance, uuid: instance_id, job: job_name, state: instance_state) }

      before {
        instance_model.active_vm = vm
        allow(Config).to receive(:current_job).and_return(update_job)
        deployment.add_instance(instance_model)
      }

      context 'when the instance is stopped hard' do
        let(:vm) { nil }
        let(:instance_state) {'detached'}

        let!(:original_disk) do
          Models::PersistentDisk.make(
            disk_cid: 'original-disk-cid',
            instance_id: instance_model.id,
            active: true,
            size: 50,
            cloud_properties: { "encrypted" => true },
            cpi: 'my-cpi',
          )
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

        context 'when disk_properties is set to copy' do
          let(:disk_properties) { 'copy' }
          it 'sets the disk size and cloud_properties to that of previous persistent disk' do
            attach_disk_job.perform
            active_disks = instance_model.persistent_disks.select { |disk| disk.active }
            expect(active_disks.first.size).to eq(50)
            expect(active_disks.first.cloud_properties).to eq({ "encrypted" => true })
          end
        end

        context 'when disk_properties is not sent' do
          let(:disk_properties) { '' }
          it 'sets the disk size to 1 so it is migrated to the desired size next deploy' do
            attach_disk_job.perform
            active_disks = instance_model.persistent_disks.select { |disk| disk.active }
            expect(active_disks.first.size).to eq(1)
            expect(active_disks.first.cloud_properties).to eq({})
          end
        end

        context 'when the instance with the given instance id cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, 'bogus', disk_cid, disk_properties) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'job_name/bogus' in deployment 'fake_deployment_name' was not found")
          end
        end

        context 'when the instance with the given job name cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, 'bogus', instance_id, disk_cid, disk_properties) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'bogus/fake_instance_id' in deployment 'fake_deployment_name' was not found")
          end
        end

        context 'when the instance with the given deployment name cannot be found' do
          let(:attach_disk_job) { Jobs::AttachDisk.new('bogus', job_name, instance_id, disk_cid, disk_properties) }
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskErrorUnknownInstance,
                                                              "Instance 'job_name/fake_instance_id' in deployment 'bogus' was not found")
          end
        end

        context 'when the instance is in a started state' do
          before do
            instance_model.update(state: 'started')
          end

          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskInvalidInstanceState,
                                                              "Instance 'job_name/fake_instance_id' in deployment 'fake_deployment_name' must be in 'bosh stopped' state")
          end
        end

        context 'when the instance is ignored' do
          before do
            instance_model.update(ignore: true)
          end
          it 'raises an error' do
            expect { attach_disk_job.perform }.to raise_error(AttachDiskInvalidInstanceState,
               "Instance 'job_name/fake_instance_id' in deployment 'fake_deployment_name' is in 'ignore' state. Attaching disks to ignored instances is not allowed.")
          end
        end

        context 'when orphaned disk is attached' do
          let!(:original_disk) do
            Models::PersistentDisk.make(
                disk_cid: 'original-disk-cid',
                instance_id: instance_model.id,
                active: true,
                size: 50,
                cpi: 'my-cpi',
            )
          end

          let!(:orphan_disk) do
            FactoryBot.create(:models_orphan_disk,
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
            FactoryBot.create(:models_orphan_snapshot,
                orphan_disk: orphan_disk,
                clean: false,
                snapshot_cid: orphan_disk.disk_cid,
                snapshot_created_at: Date.today)
          end

          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, instance_id, orphan_disk.disk_cid, disk_properties) }

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

        context 'when a new disk is attached' do
          let(:attach_disk_job) { Jobs::AttachDisk.new(deployment_name, job_name, instance_id, 'new_disk_cid', disk_properties) }

          before do
            attach_disk_job.perform
          end

          it 'has a nil CPI' do
            disk = Models::PersistentDisk.where(disk_cid:'new_disk_cid').first
            expect(disk).not_to be_nil
            expect(disk.cpi).to be_nil
          end
        end
      end

      context 'when the instance is stopped soft' do
        let(:instance_state) {'stopped'}
        let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }

        let!(:original_disk) do
          Models::PersistentDisk.make(
              disk_cid: 'original-disk-cid',
              instance_id: instance_model.id,
              active: true,
              size: 50,
              cpi: 'my-cpi',
          )
        end

        let(:agent_client) do
          instance_double(AgentClient,
            mount_disk: nil,
            wait_until_ready: nil,
            list_disk: ['original-disk-cid'],
            stop: nil,
            unmount_disk: nil
          )
        end

        before do
          allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
          allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with('').and_return(cloud)
          allow(cloud_factory).to receive(:get).with('', nil).and_return(cloud)
          allow(cloud_factory).to receive(:get).with('my-cpi').and_return(cloud)
          allow(cloud_factory).to receive(:get).with('my-cpi', nil).and_return(cloud)
          allow(cloud).to receive(:attach_disk)
          allow(cloud).to receive(:set_disk_metadata)
          allow(agent_client).to receive(:wait_until_ready)
          allow(agent_client).to receive(:add_persistent_disk)
        end

        it 'attaches the new disk and sets disk metadata' do
          expect(cloud).to receive(:attach_disk).and_return('/dev/sdf')
          expect(cloud).to receive(:set_disk_metadata).with(disk_cid, hash_including(manifest['tags']))
          expect(cloud).to receive(:detach_disk)
          expect(agent_client).to receive(:remove_persistent_disk).with('original-disk-cid')
          expect(agent_client).to receive(:wait_until_ready)
          expect(agent_client).to receive(:add_persistent_disk).with(disk_cid, '/dev/sdf')
          attach_disk_job.perform

          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.count).to eq(1)
          expect(active_disks.first.disk_cid).to eq(disk_cid)
        end

        it 'orphans and unmounts the previous disk' do
          expect(Models::OrphanDisk.all).to be_empty
          expect(cloud).to receive(:detach_disk).with(vm_cid, 'original-disk-cid')
          expect(agent_client).to receive(:remove_persistent_disk).with('original-disk-cid')
          expect(agent_client).to receive(:unmount_disk)

          attach_disk_job.perform

          expect(Models::OrphanDisk.all).not_to be_empty
        end
      end

      context 'when the job does not declare persistent disk' do
        let(:instance_state) {'stopped'}

        let(:original_disk) { nil }

        let(:agent_client) { instance_double(AgentClient, mount_disk: nil, wait_until_ready: nil) }

        let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:cloud_for_set_disk_metadata) { instance_double(Bosh::Clouds::ExternalCpi) }

        before do
          allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
          allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with('', nil).and_return(cloud)
          allow(cloud_factory).to receive(:get).with('').and_return(cloud_for_set_disk_metadata)
          allow(cloud).to receive(:attach_disk)
          allow(cloud_for_set_disk_metadata).to receive(:set_disk_metadata)
          allow(agent_client).to receive(:wait_until_ready)
          allow(agent_client).to receive(:add_persistent_disk)
        end

        it 'attaches the new disk' do
          expect(cloud).to receive(:attach_disk).and_return('/dev/sdf')
          expect(agent_client).to receive(:wait_until_ready)
          expect(agent_client).to receive(:add_persistent_disk).with(disk_cid, '/dev/sdf')
          expect(cloud_for_set_disk_metadata).to receive(:set_disk_metadata).with(disk_cid, hash_including(manifest['tags']))
          attach_disk_job.perform

          active_disks = instance_model.persistent_disks.select { |disk| disk.active }
          expect(active_disks.count).to eq(1)
          expect(active_disks.first.disk_cid).to eq(disk_cid)
        end

        it 'performs no action for previous disk' do
          expect(Models::OrphanDisk.all).to be_empty
          expect(cloud).to_not receive(:detach_disk)
          expect(agent_client).to_not receive(:unmount_disk)

          attach_disk_job.perform

          expect(Models::OrphanDisk.all).to be_empty
        end
      end
    end
  end
end
