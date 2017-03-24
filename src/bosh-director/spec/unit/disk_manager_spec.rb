require 'spec_helper'

module Bosh::Director
  describe Bosh::Director::DiskManager do
    subject(:disk_manager) { DiskManager.new(logger) }

    let(:cloud) { Config.cloud }
    let(:cloud_collection) { instance_double('Bosh::Director::CloudCollection') }
    let(:cloud_factory) { instance_double(CloudFactory) }
    let(:instance_plan) { DeploymentPlan::InstancePlan.new({
        existing_instance: instance_model,
        desired_instance: DeploymentPlan::DesiredInstance.new(job),
        instance: instance,
        network_plans: [],
        tags: tags,
      }) }
    let(:tags) {{'tags' => {'mytag' => 'myvalue'}}}

    let(:job_persistent_disk_size) { 1024 }
    let(:job) do
      job = DeploymentPlan::InstanceGroup.new(logger)
      job.name = 'job-name'
      job.persistent_disk_collection = DeploymentPlan::PersistentDiskCollection.new(logger)
      job.persistent_disk_collection.add_by_disk_type(disk_type)
      job
    end
    let(:disk_type) { DeploymentPlan::DiskType.new('disk-name', job_persistent_disk_size, {'cloud' => 'properties'}) }
    let(:instance) { DeploymentPlan::Instance.create_from_job(job, 1, 'started', nil, {}, nil, logger) }
    let(:instance_model) do
      instance = Models::Instance.make(vm_cid: 'vm234', uuid: 'my-uuid-1', availability_zone: 'az1')
      instance.add_persistent_disk(persistent_disk) if persistent_disk
      instance
    end

    let(:persistent_disk) { Models::PersistentDisk.make(disk_cid: 'disk123', size: 2048, name: disk_name, cloud_properties: {'cloud' => 'properties'}, active: true) }
    let(:disk_name) { '' }
    let(:agent_client) { instance_double(Bosh::Director::AgentClient) }

    let(:event_manager) {Api::EventManager.new(true)}
    let(:task_id) {42}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager)}

    before do
      instance.bind_existing_instance_model(instance_model)
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
      allow(agent_client).to receive(:list_disk).and_return(['disk123'])
      allow(cloud).to receive(:create_disk).and_return('new-disk-cid')
      allow(cloud_collection).to receive(:attach_disk)
      allow(cloud_collection).to receive(:detach_disk)
      allow(agent_client).to receive(:stop)
      allow(agent_client).to receive(:mount_disk)
      allow(agent_client).to receive(:wait_until_ready)
      allow(agent_client).to receive(:migrate_disk)
      allow(agent_client).to receive(:unmount_disk)
      allow(agent_client).to receive(:update_settings)
      allow(Config).to receive(:current_job).and_return(update_job)
      allow(CloudFactory).to receive(:new).and_return(cloud_factory)
    end

    describe '#attach_disk' do
      context 'managed disks' do
        it 'attaches + mounts disk' do
          expect(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).once.and_return(cloud_collection)
          expect(cloud_collection).to receive(:attach_disk).with('vm234', 'disk123')
          expect(agent_client).to receive(:wait_until_ready)
          expect(agent_client).to receive(:mount_disk).with('disk123')
          disk_manager.attach_disk(persistent_disk, {})
        end
      end

      context 'unmanaged disks' do
        it 'attaches the disk without mounting' do
          persistent_disk.update(name: 'chewbacca')
          expect(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).once.and_return(cloud_collection)
          expect(cloud_collection).to receive(:attach_disk).with('vm234', 'disk123')
          expect(agent_client).to_not receive(:mount_disk)
          disk_manager.attach_disk(persistent_disk, {})
        end
      end

      it 'sets disk metadata with deployment information' do
        allow(cloud_factory).to receive(:for_availability_zone).and_return(cloud)
        allow(cloud).to receive(:attach_disk)
        expect_any_instance_of(Bosh::Director::MetadataUpdater).to receive(:update_disk_metadata).with(cloud, persistent_disk, {'mytag' => 'myvalue'})
        disk_manager.attach_disk(persistent_disk, {'mytag' => 'myvalue'})
      end
    end

    describe '#detach_disk' do
      context 'managed disks' do
        it 'unmounts + detaches disk' do
          expect(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).once.and_return(cloud_collection)
          expect(cloud_collection).to receive(:detach_disk).with('vm234', 'disk123')
          expect(agent_client).to receive(:unmount_disk).with('disk123')
          disk_manager.detach_disk(persistent_disk)
        end
      end

      context 'unmanaged disks' do
        it 'detaches the disk without unmounting' do
          persistent_disk.update(name: 'chewbacca')
          expect(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).at_least(:once).and_return(cloud_collection)
          expect(cloud_collection).to receive(:detach_disk).with('vm234', 'disk123')
          expect(agent_client).to_not receive(:unmount_disk)
          disk_manager.detach_disk(persistent_disk)
        end
      end
    end

    describe '#update_persistent_disk' do
      before do
        allow(cloud_factory).to receive(:for_availability_zone!).with(instance_model.availability_zone).and_return(cloud)
        allow(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).and_return(cloud_collection)
      end

      context 'when disk creation fails' do
        context 'with NoDiskSpaceError' do
          let(:error) { Bosh::Clouds::NoDiskSpace.new(true) }

          it 'should raise the error' do
            expect(cloud).to receive(:create_disk).and_raise(error)
            expect {
              disk_manager.update_persistent_disk(instance_plan)
            }.to raise_error error
          end
        end
      end

      context 'when disk creation succeeds, but there is a NoDiskSpaceError during attach_disk' do
        let(:error) { Bosh::Clouds::NoDiskSpace.new(false) }

        it 'orphans the disk' do
          expect(cloud_collection).to receive(:attach_disk).and_raise(error)

          expect {
            disk_manager.update_persistent_disk(instance_plan)
          }.to raise_error error
        end
      end

      context 'when the agent reports a different disk cid from the model' do
        before do
          allow(agent_client).to receive(:list_disk).and_return(['random-disk-cid'])
        end

        context 'when uuid has not been set' do
          it 'raises' do
            expect {
              disk_manager.update_persistent_disk(instance_plan)
            }.to raise_error AgentDiskOutOfSync, "'job-name/1 (my-uuid-1)' has invalid disks: agent reports 'random-disk-cid' while director record shows 'disk123'"
          end
        end

        context 'when uuid has been set' do

          let(:instance_plan) {
            instance_model.uuid = "123-456-789"
            instance = DeploymentPlan::Instance.create_from_job(job, 1, 'started', nil, {}, nil, logger)
            instance.bind_existing_instance_model(instance_model)

            DeploymentPlan::InstancePlan.new({
               existing_instance: instance_model,
               desired_instance: DeploymentPlan::DesiredInstance.new(job),
               instance: instance,
               network_plans: [],
            })
          }

          it 'raises' do
            expect {
              disk_manager.update_persistent_disk(instance_plan)
            }.to raise_error AgentDiskOutOfSync, "'job-name/1 (123-456-789)' has invalid disks: agent reports 'random-disk-cid' while director record shows 'disk123'"
          end
        end
      end

      context 'when the agent reports a disk cid consistent with the model' do
        let!(:inactive_disk) do
          Models::PersistentDisk.make(
            disk_cid: 'inactive-disk',
            active: false,
            instance: instance_model,
            size: 54,
            cloud_properties: {'cloud-props' => 'something'}
          )
        end

        it 'logs when the disks are inactive' do
          expect(logger).to receive(:warn).with("'job-name/1 (my-uuid-1)' has inactive disk inactive-disk")
          disk_manager.update_persistent_disk(instance_plan)
        end

        it 'stores events' do
          expect {
            disk_manager.update_persistent_disk(instance_plan)
          }.to change {
          Bosh::Director::Models::Event.count }.from(0).to(6)

          event_1 = Bosh::Director::Models::Event.first
          expect(event_1.user).to eq('user')
          expect(event_1.action).to eq('create')
          expect(event_1.object_type).to eq('disk')
          expect(event_1.object_name).to eq(nil)
          expect(event_1.task).to eq("#{task_id}")
          expect(event_1.deployment).to eq(instance_model.deployment.name)
          expect(event_1.instance).to eq(instance_model.name)

          event_2 = Bosh::Director::Models::Event.order(:id)[2]
          expect(event_2.parent_id).to eq(1)
          expect(event_2.user).to eq('user')
          expect(event_2.action).to eq('create')
          expect(event_2.object_type).to eq('disk')
          expect(event_2.object_name).to eq('new-disk-cid')
          expect(event_2.task).to eq("#{task_id}")
          expect(event_2.deployment).to eq(instance_model.deployment.name)
          expect(event_2.instance).to eq(instance_model.name)
        end

        it 'stores events with error information' do
          allow(cloud).to receive(:create_disk).and_raise(Exception, 'error')
          expect {
            disk_manager.update_persistent_disk(instance_plan)
          }.to raise_error Exception, 'error'

          event_2 = Bosh::Director::Models::Event.order(:id)[2]
          expect(event_2.error).to eq('error')
        end

        context 'when the persistent disk is changed' do
          before { expect(instance_plan.persistent_disk_changed?).to be_truthy }

          context 'when the instance group has persistent disk type and the disk type is non zero' do
            it 'calls to the cpi to create the disk specified by the job' do
              expect(cloud).to receive(:create_disk).with(1024, {'cloud' => 'properties'}, 'vm234').and_return('new-disk-cid')
              disk_manager.update_persistent_disk(instance_plan)
            end

            it 'creates a persistent disk record' do
              disk_manager.update_persistent_disk(instance_plan)
              model = Models::PersistentDisk.where(instance_id: instance_model.id, size: 1024).first
              expect(model.cloud_properties).to eq({'cloud' => 'properties'})
            end

            it 'attaches the disk to the vm' do
              expect(cloud_collection).to receive(:attach_disk).with('vm234', 'new-disk-cid')
              disk_manager.update_persistent_disk(instance_plan)
            end

            context 'when the new disk fails to attach with no disk space error' do
              let(:no_space) { Bosh::Clouds::NoDiskSpace.new(true) }

              before do
                expect(cloud_collection).to receive(:attach_disk).with('vm234', 'new-disk-cid').once.and_raise(no_space)
              end

              it 'raises the error' do
                expect {
                  disk_manager.update_persistent_disk(instance_plan)
                }.to raise_error no_space
              end
            end

            context 'when the disk is managed' do
              it 'does not associate managed disk models' do
                expect(agent_client).to_not receive(:update_settings)
              end

              it 'mounts the new disk' do
                expect(agent_client).to receive(:mount_disk).with('new-disk-cid')
                disk_manager.update_persistent_disk(instance_plan)
              end

              context 'where there is an old disk to migrate' do
                it 'migrates the disk' do
                  expect(agent_client).to receive(:migrate_disk).with('disk123', 'new-disk-cid')
                  disk_manager.update_persistent_disk(instance_plan)
                end
              end

              context 'when there is no old disk to migrate' do
                let(:persistent_disk) { nil }
                before do
                  allow(agent_client).to receive(:list_disk).and_return([])
                end

                it 'does not attempt to migrate the disk' do
                  expect(agent_client).to_not receive(:migrate_disk)
                  disk_manager.update_persistent_disk(instance_plan)
                end

                it 'mounts the new disk' do
                  expect(agent_client).to receive(:mount_disk).with('new-disk-cid')
                  disk_manager.update_persistent_disk(instance_plan)
                end
              end

              context 'mounting and migrating to the new disk' do
                let(:disk_error) { StandardError.new }

                context 'when mounting and migrating disks succeeds' do
                  before do
                    allow(cloud_collection).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                    allow(agent_client).to receive(:list_disk).and_return(['disk123', 'new-disk-cid'])
                  end

                  it 'switches active disks' do
                    disk_manager.update_persistent_disk(instance_plan)
                    expect(Models::PersistentDisk.where(instance_id: instance_model.id, disk_cid: 'new-disk-cid', active: true).first).to_not be_nil
                  end

                  context 'when switching active disk succeeds' do
                    let(:snapshot) { Models::Snapshot.make }
                    before do
                      persistent_disk.add_snapshot(snapshot)
                      allow(agent_client).to receive(:unmount_disk).with('disk123')
                      allow(cloud_collection).to receive(:detach_disk).with('vm234', 'disk123')
                    end

                    it 'orphans the old mounted disk' do
                      expect(agent_client).to receive(:unmount_disk).with('disk123')
                      expect(cloud_collection).to receive(:detach_disk).with('vm234', 'disk123')

                      disk_manager.update_persistent_disk(instance_plan)

                      expect(Models::PersistentDisk.where(disk_cid: 'disk123').first).to be_nil
                    end

                    it 'orphans additional inactive disks' do
                      expect(cloud_collection).to receive(:detach_disk).with('vm234', 'inactive-disk')

                      disk_manager.update_persistent_disk(instance_plan)
                      expect(Models::PersistentDisk.where(disk_cid: 'inactive-disk').first).to be_nil

                      orphan_disk = Models::OrphanDisk.where(disk_cid: 'inactive-disk').first
                      expect(orphan_disk.size).to eq(54)
                      expect(orphan_disk.availability_zone).to eq(instance_model.availability_zone)
                      expect(orphan_disk.deployment_name).to eq(instance_model.deployment.name)
                      expect(orphan_disk.instance_name).to eq("#{instance_model.job}/#{instance_model.uuid}")
                      expect(orphan_disk.cloud_properties).to eq({'cloud-props' => 'something'})
                    end
                  end
                end

                context 'when mounting the disk raises' do
                  before do
                    allow(agent_client).to receive(:list_disk).and_return(['disk123'])
                    expect(agent_client).to receive(:mount_disk).with('new-disk-cid').and_raise(disk_error)
                  end

                  it 'deletes the disk and re-raises the error' do
                    expect(agent_client).to_not receive(:unmount_disk)
                    expect(cloud_collection).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                    expect {
                      disk_manager.update_persistent_disk(instance_plan)
                    }.to raise_error disk_error
                    expect(Models::PersistentDisk.where(disk_cid: 'new-disk-cid').all).to eq([])
                  end
                end

                context 'when migrating the disk raises' do
                  before do
                    allow(agent_client).to receive(:list_disk).and_return(['disk123', 'new-disk-cid'])
                    allow(agent_client).to receive(:mount_disk).with('new-disk-cid')
                    expect(agent_client).to receive(:migrate_disk).with('disk123', 'new-disk-cid').and_raise(disk_error)
                  end

                  it 'deletes the disk and re-raises the error' do
                    expect(agent_client).to receive(:unmount_disk).with('new-disk-cid')
                    expect(cloud_collection).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                    expect {
                      disk_manager.update_persistent_disk(instance_plan)
                    }.to raise_error disk_error
                    expect(Models::PersistentDisk.where(disk_cid: 'new-disk-cid').all).to eq([])
                  end
                end
              end
            end
          end
        end

        context 'when the persistent disk has not changed' do
          let(:job_persistent_disk_size) { 2048 }

          before do
            expect(instance_plan.persistent_disk_changed?).to_not be_truthy
          end

          it 'does not migrate the disk' do
            expect(cloud).to_not receive(:create_disk)
            disk_manager.update_persistent_disk(instance_plan)
          end
        end
      end

      context 'when agent reports no disks attached' do
        before do
          allow(agent_client).to receive(:list_disk).and_return([])
        end

        context 'when we no longer need disk' do
          let(:job) do
            job = DeploymentPlan::InstanceGroup.new(logger)
            job.name = 'job-name'
            job.persistent_disk_collection = DeploymentPlan::PersistentDiskCollection.new(logger)
            job
          end

          it 'orphans disk' do
            expect(Models::PersistentDisk.all.size).to eq(1)
            expect(Models::OrphanDisk.all.size).to eq(0)

            disk_manager.update_persistent_disk(instance_plan)

            expect(Models::PersistentDisk.all.size).to eq(0)
            expect(Models::OrphanDisk.all.size).to eq(1)
            expect(Models::OrphanDisk.first.disk_cid).to eq('disk123')
          end
        end

        context 'when we still need disk' do
          let(:job_persistent_disk_size) { 100 }

          it 'raises' do
            expect {
              disk_manager.update_persistent_disk(instance_plan)
            }.to raise_error AgentDiskOutOfSync, "'job-name/1 (my-uuid-1)' has invalid disks: agent reports '' while director record shows 'disk123'"
          end
        end
      end

      context 'when instance has no persistent disk' do
        let(:persistent_disk) { nil }

        it 'does not raise' do
          expect {
            disk_manager.update_persistent_disk(instance_plan)
          }.not_to raise_error
        end
      end
    end

    describe '#delete_persistent_disks' do
      let(:snapshot) { Models::Snapshot.make(persistent_disk: persistent_disk) }
      before { persistent_disk.add_snapshot(snapshot) }

      it 'deletes snapshots' do
        expect(Models::Snapshot.all.size).to eq(1)
        disk_manager.delete_persistent_disks(instance_model)
        expect(Models::Snapshot.all.size).to eq(0)
      end

      it 'deletes disks for instance' do
        expect(Models::PersistentDisk.all.size).to eq(1)
        disk_manager.delete_persistent_disks(instance_model)
        expect(Models::PersistentDisk.all.size).to eq(0)
      end

      it 'does not delete disk and snapshots from cloud' do
        expect(cloud_collection).to_not receive(:delete_snapshot)
        expect(cloud_collection).to_not receive(:delete_disk)

        disk_manager.delete_persistent_disks(instance_model)
      end

      it 'stores events' do
        expect {
          disk_manager.delete_persistent_disks(instance_model)
        }.to change {
          Bosh::Director::Models::Event.count }.from(0).to(2)

        event_1 = Bosh::Director::Models::Event.first
        expect(event_1.user).to eq('user')
        expect(event_1.action).to eq('delete')
        expect(event_1.object_type).to eq('disk')
        expect(event_1.object_name).to eq('disk123')
        expect(event_1.task).to eq("#{task_id}")
        expect(event_1.deployment).to eq(instance_model.deployment.name)
        expect(event_1.instance).to eq(instance_model.name)

        event_2 = Bosh::Director::Models::Event.order(:id).last
        expect(event_2.parent_id).to eq(1)
        expect(event_2.user).to eq('user')
        expect(event_2.action).to eq('delete')
        expect(event_2.object_type).to eq('disk')
        expect(event_2.object_name).to eq('disk123')
        expect(event_2.task).to eq("#{task_id}")
        expect(event_2.deployment).to eq(instance_model.deployment.name)
        expect(event_2.instance).to eq(instance_model.name)
      end
    end

    describe '#unmount_disk_for' do
      it 'deletes the old mounted disk' do
        expect(agent_client).to receive(:unmount_disk).with('disk123')
        disk_manager.unmount_disk_for(instance_plan)
      end
    end

    describe '#attach_disks_if_needed' do
      context 'when instance desired job has disk' do
        let(:job_persistent_disk_size) { 100 }

        it 'attaches current instance disk' do
          expect(cloud_collection).to receive(:attach_disk).with('vm234', 'disk123')
          expect(cloud_collection).to receive(:set_disk_metadata).with('disk123', hash_including(tags))
          expect(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).at_least(:once).and_return(cloud_collection)
          disk_manager.attach_disks_if_needed(instance_plan)
        end
      end

      context 'when instance desired job does not have disk' do
        let(:job) do
          job = DeploymentPlan::InstanceGroup.new(logger)
          job.name = 'job-name'
          job.persistent_disk_collection = DeploymentPlan::PersistentDiskCollection.new(logger)
          job
        end

        it 'does not attach current instance disk' do
          expect(cloud).to_not receive(:attach_disk)
          disk_manager.attach_disks_if_needed(instance_plan)
        end
      end
    end
  end
end
