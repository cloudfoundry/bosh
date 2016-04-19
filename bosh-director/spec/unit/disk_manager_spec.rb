require 'spec_helper'

module Bosh::Director
  describe Bosh::Director::DiskManager do
    subject(:disk_manager) { DiskManager.new(cloud, logger) }

    let(:cloud) { instance_double(Bosh::Cloud) }
    let(:instance_plan) { DeploymentPlan::InstancePlan.new({
        existing_instance: instance_model,
        desired_instance: DeploymentPlan::DesiredInstance.new(job),
        instance: instance,
        network_plans: [],
      }) }

    let(:job_persistent_disk_size) { 1024 }
    let(:job) do
      job = DeploymentPlan::Job.new(logger)
      job.name = 'job-name'
      job.persistent_disk_type = DeploymentPlan::DiskType.new('disk-name', job_persistent_disk_size, {'cloud' => 'properties'})
      job
    end
    let(:instance) { DeploymentPlan::Instance.create_from_job(job, 1, 'started', nil, {}, nil, logger) }
    let(:instance_model) do
      instance = Models::Instance.make(vm_cid: 'vm234', uuid: 'my-uuid-1')
      instance.add_persistent_disk(persistent_disk) if persistent_disk
      instance
    end

    let(:persistent_disk) { Models::PersistentDisk.make(disk_cid: 'disk123', size: 2048, cloud_properties: {'cloud' => 'properties'}, active: true) }
    let(:agent_client) { instance_double(Bosh::Director::AgentClient) }

    let(:event_manager) {Api::EventManager.new(true)}
    let(:task_id) {42}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager)}

    before do
      instance.bind_existing_instance_model(instance_model)
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
      allow(agent_client).to receive(:list_disk).and_return(['disk123'])
      allow(cloud).to receive(:create_disk).and_return('new-disk-cid')
      allow(cloud).to receive(:attach_disk)
      allow(agent_client).to receive(:stop)
      allow(agent_client).to receive(:mount_disk)
      allow(agent_client).to receive(:migrate_disk)
      allow(agent_client).to receive(:unmount_disk)
      allow(cloud).to receive(:detach_disk)
      allow(Config).to receive(:cloud).and_return(cloud)
      allow(Config).to receive(:current_job).and_return(update_job)
    end

    describe '#update_persistent_disk' do
      context 'when disk creation fails' do
        context 'with NoDiskSpaceError' do
          let(:error) { Bosh::Clouds::NoDiskSpace.new(true) }

          before do
            allow(cloud).to receive(:create_disk).and_raise(error)
          end

          it 'should raise the error' do
            expect {
              disk_manager.update_persistent_disk(instance_plan)
            }.to raise_error error
          end
        end
      end

      context 'when disk creation succeeds, but there is a NoDiskSpaceError during attach_disk' do
        let(:error) { Bosh::Clouds::NoDiskSpace.new(false) }

        it 'orphans the disk' do
          allow(cloud).to receive(:attach_disk).and_raise(error)

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
            cloud_properties: "cloud-props"
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

          context 'when the job has persistent disk type and the disk type is non zero' do
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
              expect(cloud).to receive(:attach_disk).with('vm234', 'new-disk-cid')
              disk_manager.update_persistent_disk(instance_plan)
            end

            context 'when the new disk fails to attach with no disk space error' do
              let(:no_space) { Bosh::Clouds::NoDiskSpace.new(true) }

              before do
                expect(cloud).to receive(:attach_disk).with('vm234', 'new-disk-cid').once.and_raise(no_space)
              end

              it 'raises the error' do
                expect {
                  disk_manager.update_persistent_disk(instance_plan)
                }.to raise_error no_space
              end
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
              it 'does not attempt to migrate the disk' do
                expect(agent_client).to_not receive(:migrate_disk)
              end
            end

            context 'mounting and migrating to the new disk' do
              let(:disk_error) { StandardError.new }

              context 'when mounting and migrating disks succeeds' do
                before do
                  allow(cloud).to receive(:detach_disk).with('vm234', 'new-disk-cid')
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
                    allow(cloud).to receive(:detach_disk).with('vm234', 'disk123')
                  end

                  it 'orphans the old mounted disk' do
                    expect(agent_client).to receive(:unmount_disk).with('disk123')
                    expect(cloud).to receive(:detach_disk).with('vm234', 'disk123')

                    disk_manager.update_persistent_disk(instance_plan)

                    expect(Models::PersistentDisk.where(disk_cid: 'disk123').first).to be_nil
                  end

                  it 'orphans additional inactive disks' do
                    expect(cloud).to receive(:detach_disk).with('vm234', 'inactive-disk')

                    disk_manager.update_persistent_disk(instance_plan)
                    expect(Models::PersistentDisk.where(disk_cid: 'inactive-disk').first).to be_nil

                    orphan_disk = Models::OrphanDisk.where(disk_cid: 'inactive-disk').first
                    expect(orphan_disk.size).to eq(54)
                    expect(orphan_disk.availability_zone).to eq(instance_model.availability_zone)
                    expect(orphan_disk.deployment_name).to eq(instance_model.deployment.name)
                    expect(orphan_disk.instance_name).to eq("#{instance_model.job}/#{instance_model.uuid}")
                    expect(orphan_disk.cloud_properties).to eq('cloud-props')
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
                  expect(cloud).to receive(:detach_disk).with('vm234', 'new-disk-cid')
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
                  expect(cloud).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                  expect {
                    disk_manager.update_persistent_disk(instance_plan)
                  }.to raise_error disk_error
                  expect(Models::PersistentDisk.where(disk_cid: 'new-disk-cid').all).to eq([])
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
          let(:job_persistent_disk_size) { 0 }

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
        expect(cloud).to_not receive(:delete_snapshot)
        expect(cloud).to_not receive(:delete_disk)

        disk_manager.delete_persistent_disks(instance_model)
      end

      it "stores events" do
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

    describe '#orphan_disk' do
      it 'orphans disks and snapshots' do
        snapshot = Models::Snapshot.make(persistent_disk: persistent_disk)

        disk_manager.orphan_disk(persistent_disk)
        orphan_disk = Models::OrphanDisk.first
        orphan_snapshot = Models::OrphanSnapshot.first

        expect(orphan_disk.disk_cid).to eq(persistent_disk.disk_cid)
        expect(orphan_snapshot.snapshot_cid).to eq(snapshot.snapshot_cid)
        expect(orphan_snapshot.orphan_disk).to eq(orphan_disk)

        expect(Models::PersistentDisk.all.count).to eq(0)
        expect(Models::Snapshot.all.count).to eq(0)
      end

      it 'should transactionally move orphan disks and snapshots' do
        conflicting_orphan_disk = Models::OrphanDisk.make
        conflicting_orphan_snapshot = Models::OrphanSnapshot.make(
          orphan_disk: conflicting_orphan_disk,
          snapshot_cid: 'existing_cid',
          snapshot_created_at: 0
        )

        snapshot = Models::Snapshot.make(
          snapshot_cid: 'existing_cid',
          persistent_disk: persistent_disk
        )

        expect { disk_manager.orphan_disk(persistent_disk) }.to raise_error(Sequel::ValidationFailed)

        conflicting_orphan_snapshot.destroy
        conflicting_orphan_disk.destroy

        expect(Models::PersistentDisk.all.count).to eq(1)
        expect(Models::Snapshot.all.count).to eq(1)
        expect(Models::OrphanDisk.all.count).to eq(0)
        expect(Models::OrphanSnapshot.all.count).to eq(0)
      end
    end

    describe '#list_orphan_disk' do
      it 'returns an array of orphaned disks as hashes' do
        orphaned_at = Time.now.utc
        other_orphaned_at = Time.now.utc
        Models::OrphanDisk.make(
          disk_cid: 'random-disk-cid-1',
          instance_name: 'fake-name-1',
          size: 10,
          deployment_name: 'fake-deployment',
          created_at: orphaned_at,
        )
        Models::OrphanDisk.make(
          disk_cid: 'random-disk-cid-2',
          instance_name: 'fake-name-2',
          availability_zone: 'az2',
          deployment_name: 'fake-deployment',
          created_at: other_orphaned_at,
          cloud_properties: {'cloud' => 'properties'}
        )

        expect(subject.list_orphan_disks).to eq([
              {
                'disk_cid' => 'random-disk-cid-1',
                'size' => 10,
                'az' => nil,
                'deployment_name' => 'fake-deployment',
                'instance_name' => 'fake-name-1',
                'cloud_properties' => {},
                'orphaned_at' => orphaned_at.to_s
              },
              {
                'disk_cid' => 'random-disk-cid-2',
                'size' => nil,
                'az' => 'az2',
                'deployment_name' => 'fake-deployment',
                'instance_name' => 'fake-name-2',
                'cloud_properties' => {'cloud' => 'properties'},
                'orphaned_at' => other_orphaned_at.to_s
              }
            ])
      end
    end

    describe 'Deleting orphans' do
      let(:time) { Time.now.utc }
      let(:ten_seconds_ago) { time - 10 }
      let(:six_seconds_ago) { time - 6 }
      let(:five_seconds_ago) { time - 5 }
      let(:four_seconds_ago) { time - 4 }

      let(:event_log) { instance_double(EventLog::Log) }
      let(:stage) { instance_double(EventLog::Stage) }
      let(:orphan_disk_1) { Models::OrphanDisk.make(disk_cid: 'disk-cid-1', created_at: ten_seconds_ago) }
      let(:orphan_disk_2) { Models::OrphanDisk.make(disk_cid: 'disk-cid-2', created_at: five_seconds_ago) }
      let(:orphan_disk_cid_1) { orphan_disk_1.disk_cid }
      let(:orphan_disk_cid_2) { orphan_disk_2.disk_cid }
      let!(:orphan_disk_snapshot_1a) { Models::OrphanSnapshot.make(orphan_disk: orphan_disk_1, created_at: 0, snapshot_cid: 'snap-cid-a') }
      let!(:orphan_disk_snapshot_1b) { Models::OrphanSnapshot.make(orphan_disk: orphan_disk_1, created_at: 0, snapshot_cid: 'snap-cid-b') }
      let!(:orphan_disk_snapshot_2) { Models::OrphanSnapshot.make(orphan_disk: orphan_disk_2, created_at: 0, snapshot_cid: 'snap-cid-2') }
      before do
        allow(cloud).to receive(:delete_disk)
        allow(cloud).to receive(:delete_snapshot)
        allow(event_log).to receive(:begin_stage).and_return(stage)
        allow(stage).to receive(:advance_and_track).and_yield
      end

      describe 'deleting an orphan disk by disk cid' do
        it 'deletes disks from the cloud and from the db' do
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)

          subject.delete_orphan_disk_by_disk_cid(orphan_disk_cid_1)

          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).to be_empty
          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_2).all).to_not be_empty
        end

        it 'deletes the orphan snapshots' do
          expect(Models::OrphanSnapshot.all).to_not be_empty
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-a')
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-b')
          expect(cloud).to_not receive(:delete_snapshot).with('snap-cid-2')

          subject.delete_orphan_disk_by_disk_cid(orphan_disk_cid_1)

          expect(Models::OrphanSnapshot.all.map(&:snapshot_cid)).to eq(['snap-cid-2'])
        end

        context 'when user accidentally tries to delete an non-existent disk' do
          it 'raises DiskNotFound AND continues to delete the remaining disks' do
            expect(logger).to receive(:debug).with('Disk not found: non_existing_orphan_disk_cid')

            subject.delete_orphan_disk_by_disk_cid('non_existing_orphan_disk_cid')
          end
        end
      end

      describe 'deleting an orphan disk' do
        it 'deletes disks from the cloud and from the db' do
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)

          subject.delete_orphan_disk(orphan_disk_1)

          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).to be_empty
          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_2).all).to_not be_empty
        end

        it 'deletes the orphan snapshots' do
          expect(Models::OrphanSnapshot.all).to_not be_empty
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-a')
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-b')
          expect(cloud).to_not receive(:delete_snapshot).with('snap-cid-2')

          subject.delete_orphan_disk(orphan_disk_1)

          expect(Models::OrphanSnapshot.all.map(&:snapshot_cid)).to eq(['snap-cid-2'])
        end

        context 'when the snapshot is not found in the cloud' do
          it 'logs the error and continues to delete the remaining disks' do
            expect(cloud).to receive(:delete_snapshot).with('snap-cid-a').and_raise(Bosh::Clouds::DiskNotFound.new(false))
            expect(logger).to receive(:debug).with('Disk not found in IaaS: snap-cid-a')
            subject.delete_orphan_disk(orphan_disk_1)
            expect(Models::OrphanSnapshot.where(orphan_disk_id: orphan_disk_1.id).all).to be_empty
          end
        end

        context 'when disk is not found in the cloud' do
          it 'logs the error to the debug log AND continues to delete the remaining disks' do
            allow(cloud).to receive(:delete_disk).with(orphan_disk_cid_1).and_raise(Bosh::Clouds::DiskNotFound.new(false))

            expect(logger).to receive(:debug).with("Disk not found in IaaS: #{orphan_disk_cid_1}")

            subject.delete_orphan_disk(orphan_disk_1)
            expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).to be_empty
          end
        end

        context 'when CPI is unable to delete a disk' do
          it 'raises the error thrown by the CPI AND does NOT delete the disk from the database' do
            allow(cloud).to receive(:delete_disk).with(orphan_disk_cid_1).and_raise(Exception.new('Bad stuff happened!'))

            expect {
              subject.delete_orphan_disk(orphan_disk_1)
            }.to raise_error Exception, 'Bad stuff happened!'

            expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).not_to be_empty
          end
        end
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
          expect(cloud).to receive(:attach_disk).with('vm234', 'disk123')
          disk_manager.attach_disks_if_needed(instance_plan)
        end
      end

      context 'when instance desired job does not have disk' do
        let(:job_persistent_disk_size) { 0 }

        it 'does not attach current instance disk' do
          expect(cloud).to_not receive(:attach_disk)
          disk_manager.attach_disks_if_needed(instance_plan)
        end
      end
    end
  end
end
