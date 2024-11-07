require 'spec_helper'

module Bosh::Director
  describe Bosh::Director::DiskManager do
    subject(:disk_manager) { DiskManager.new(logger) }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:enable_cpi_resize_disk) { false }
    let(:enable_cpi_update_disk) { false }
    let(:cloud_factory) { instance_double(CloudFactory) }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new(existing_instance: instance_model,
                                       desired_instance: DeploymentPlan::DesiredInstance.new(instance_group),
                                       instance: instance,
                                       network_plans: [],
                                       tags: tags,
                                       variables_interpolator: variables_interpolator)
    end
    let(:tags) do
      { 'tags' => { 'mytag' => 'myvalue' } }
    end

    let(:job_persistent_disk_size) { 1024 }

    let(:disk_collection) do
      collection = DeploymentPlan::PersistentDiskCollection.new(logger)
      collection.add_by_disk_type(disk_type)
      collection
    end

    let(:instance_group) do
      FactoryBot.build(:deployment_plan_instance_group,
        name: 'job-name',
        persistent_disk_collection: disk_collection,
      )
    end

    let(:disk_type) { DeploymentPlan::DiskType.new('disk-name', job_persistent_disk_size, cloud_properties) }
    let(:deployment_model) { FactoryBot.create(:models_deployment, name: 'dep1') }
    let(:instance) { DeploymentPlan::Instance.create_from_instance_group(instance_group, 1, 'started', deployment_model, {}, nil, logger, variables_interpolator) }
    let(:instance_model) do
      FactoryBot.create(:models_instance, uuid: 'my-uuid-1', availability_zone: 'az1', variable_set_id: variable_set.id).tap do |i|
        FactoryBot.create(:models_vm, cid: 'vm234', instance_id: i.id, active: true, cpi: 'my-cpi')
        i.add_persistent_disk(persistent_disk) if persistent_disk
      end.reload
    end

    let(:persistent_disk) { FactoryBot.create(:models_persistent_disk, disk_cid: 'disk123', size: 2048, name: disk_name, cloud_properties: cloud_properties, active: true, cpi: 'my-cpi') }
    let(:cloud_properties) do
      { 'cloud' => 'properties' }
    end
    let(:disk_name) { '' }
    let(:agent_client) { instance_double(Bosh::Director::AgentClient) }

    let(:event_manager) { Api::EventManager.new(true) }
    let(:task_id) { 42 }
    let(:update_job) { instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager) }
    let(:step_report) { instance_double(Bosh::Director::DeploymentPlan::Stages::Report) }
    let(:disk_hint) { '/dev/sdc' }
    let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

    before do
      allow(deployment_model).to receive(:last_successful_variable_set).and_return(variable_set)
      instance.bind_existing_instance_model(instance_model)
      allow(AgentClient).to receive(:with_agent_id).with(instance_model.agent_id, instance_model.name).and_return(agent_client)
      allow(agent_client).to receive(:list_disk).and_return(['disk123'])
      allow(cloud).to receive(:create_disk).and_return('new-disk-cid')
      allow(cloud).to receive(:resize_disk)
      allow(cloud).to receive(:update_disk)
      allow(cloud).to receive(:attach_disk)
      allow(cloud).to receive(:detach_disk)
      allow(agent_client).to receive(:stop)
      allow(agent_client).to receive(:mount_disk)
      allow(agent_client).to receive(:wait_until_ready)
      allow(agent_client).to receive(:migrate_disk)
      allow(agent_client).to receive(:unmount_disk)
      allow(agent_client).to receive(:remove_persistent_disk)
      allow(agent_client).to receive(:update_settings)
      allow(agent_client).to receive(:add_persistent_disk)
      allow(Config).to receive(:current_job).and_return(update_job)
      allow(Config).to receive(:enable_cpi_resize_disk).and_return(enable_cpi_resize_disk)
      allow(Config).to receive(:enable_cpi_update_disk).and_return(enable_cpi_update_disk)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(DeploymentPlan::Stages::Report).to receive(:new).and_return(step_report)
      allow(step_report).to receive(:disk_hint).and_return(disk_hint)
      allow(step_report).to receive(:disk_hint=)
    end

    describe '#attach_disk' do
      let(:attach_step) { instance_double(DeploymentPlan::Steps::AttachDiskStep, perform: nil) }
      let(:tags) do
        {}
      end

      before do
        allow(DeploymentPlan::Steps::AttachDiskStep).to receive(:new)
          .with(persistent_disk, tags).and_return(attach_step)
      end

      context 'managed disks' do
        it 'attaches + mounts disk' do
          expect(attach_step).to receive(:perform)
          expect(agent_client).to receive(:wait_until_ready)
          expect(agent_client).to receive(:mount_disk).with('disk123')
          disk_manager.attach_disk(persistent_disk, tags)
        end
      end

      context 'unmanaged disks' do
        it 'attaches the disk without mounting' do
          persistent_disk.update(name: 'chewbacca')
          expect(attach_step).to receive(:perform)
          expect(agent_client).to_not receive(:mount_disk)
          disk_manager.attach_disk(persistent_disk, tags)
        end
      end

      context 'when tags are set' do
        let(:tags) do
          { 'mytag' => 'myvalue' }
        end

        it 'passes tags to attach step' do
          expect(attach_step).to receive(:perform)
          disk_manager.attach_disk(persistent_disk, tags)
        end
      end
    end

    describe '#detach_disk' do
      context 'managed disks' do
        it 'unmounts + detaches disk' do
          expect(cloud_factory).to receive(:get).with(persistent_disk.cpi, nil).once.and_return(cloud)
          expect(cloud).to receive(:detach_disk).with('vm234', 'disk123')
          expect(agent_client).to receive(:unmount_disk).with('disk123')
          expect(agent_client).to receive(:remove_persistent_disk).with('disk123')
          disk_manager.detach_disk(persistent_disk)
        end
      end

      context 'unmanaged disks' do
        it 'detaches the disk without unmounting' do
          persistent_disk.update(name: 'chewbacca')
          expect(cloud_factory).to receive(:get).with(persistent_disk.cpi, nil).at_least(:once).and_return(cloud)
          expect(cloud).to receive(:detach_disk).with('vm234', 'disk123')
          expect(agent_client).to receive(:remove_persistent_disk).with('disk123')
          expect(agent_client).to_not receive(:unmount_disk)
          disk_manager.detach_disk(persistent_disk)
        end
      end
    end

    describe '#update_persistent_disk' do
      before do
        allow(cloud_factory).to receive(:get).with('my-cpi', nil).and_return(cloud)
        allow(cloud_factory).to receive(:get).with('my-cpi').and_return(cloud)
      end

      it 'passes correct variable sets for comparing disks' do
        desired_variable_set = FactoryBot.create(:models_variable_set, deployment: deployment_model)
        instance_plan.instance.desired_variable_set = desired_variable_set

        expect(Bosh::Director::DeploymentPlan::PersistentDiskCollection).to receive(:changed_disk_pairs).with(
          anything,
          instance_plan.instance.previous_variable_set,
          anything,
          desired_variable_set,
        ).and_return([])

        disk_manager.update_persistent_disk(instance_plan)
      end

      context 'when `enable_cpi_update_disk` is enabled' do
        let(:enable_cpi_update_disk) { true }
        let(:job_persistent_disk_size) { 4096 }
        let(:cloud_properties) do
          { 'new' => 'properties' }
        end

        context 'when disk size and properties change' do
          it 'updates the disk via cpi' do
            disk_manager.update_persistent_disk(instance_plan)

            expect(agent_client).to have_received(:unmount_disk)
            expect(agent_client).to have_received(:remove_persistent_disk)
            expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123')
            expect(cloud).to have_received(:update_disk).with('disk123', 4096, { "new" => "properties" })
            expect(cloud).to have_received(:attach_disk).with('vm234', 'disk123')
            expect(agent_client).to have_received(:mount_disk)
          end

          it 'updates the disk size and cloud properties in the db' do
            disk_manager.update_persistent_disk(instance_plan)

            model = Models::PersistentDisk.where(disk_cid: 'disk123').first
            expect(model.size).to eq(job_persistent_disk_size)
            expect(model.cloud_properties).to eq(cloud_properties)
          end
        end

        context 'when the new disk is unmanaged' do
          let(:disk_collection) do
            collection = DeploymentPlan::PersistentDiskCollection.new(logger)
            collection.add_by_disk_name_and_type('unmanaged-disk-name', disk_type)
            collection
          end

          context 'when the old disk is unmanaged' do
            let(:disk_name) { 'unmanaged-disk-name' }

            it 'does not use cpi update_disk' do
              disk_manager.update_persistent_disk(instance_plan)

              expect(cloud).to_not have_received(:update_disk)
            end
          end

          context 'when the old disk is managed' do
            let(:disk_name) { '' }

            it 'does not use cpi update_disk' do
              expect do
                disk_manager.update_persistent_disk(instance_plan)
              end.not_to raise_error

              expect(cloud).to_not have_received(:update_disk)
            end
          end
        end

        context 'when update_disk is not implemented' do
          it 'falls back to manually copying disk' do
            allow(cloud).to receive(:update_disk).and_raise(Bosh::Clouds::NotImplemented)

            disk_manager.update_persistent_disk(instance_plan)

            expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123').twice
            expect(cloud).to have_received(:update_disk)
            expect(cloud).to have_received(:create_disk).with(4096, { 'new' => 'properties' }, 'vm234')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'disk123')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'new-disk-cid')
          end
        end

        context 'when update_disk is not supported' do
          let(:job_persistent_disk_size) { 3072 }

          it 'falls back to manually copying disk' do
            allow(cloud).to receive(:update_disk).and_raise(Bosh::Clouds::NotSupported)

            disk_manager.update_persistent_disk(instance_plan)

            expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123').twice
            expect(cloud).to have_received(:update_disk)
            expect(cloud).to have_received(:create_disk).with(3072, { 'new' => 'properties' }, 'vm234')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'disk123')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'new-disk-cid')
          end
        end
      end

      context 'when `enable_cpi_update_disk` is disabled' do
        let(:enable_cpi_update_disk) { false }
        let(:cloud_properties) do
          { 'other' => 'properties' }
        end

        it 'falls back to manually copying disk' do
          disk_manager.update_persistent_disk(instance_plan)

          expect(cloud).not_to have_received(:update_disk)
          expect(cloud).to have_received(:create_disk).with(1024, { 'other' => 'properties' }, 'vm234')
          expect(cloud).to have_received(:attach_disk).with('vm234', 'new-disk-cid')
          expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123')
        end
      end

      context 'when `enable_cpi_disk_resize` is enabled' do
        let(:enable_cpi_resize_disk) { true }
        let(:job_persistent_disk_size) { 4096 }

        context 'when only disk size has changed' do
          context 'when it is a managed disk' do
            it 'resizes the disk via CPI' do
              disk_manager.update_persistent_disk(instance_plan)

              expect(agent_client).to have_received(:unmount_disk)
              expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123')
              expect(cloud).to have_received(:resize_disk).with('disk123', 4096)
              expect(cloud).to have_received(:attach_disk).with('vm234', 'disk123')
              expect(agent_client).to have_received(:remove_persistent_disk).with('disk123')
              expect(agent_client).to have_received(:mount_disk)
            end

            it 'updates the old disk in the db' do
              disk_manager.update_persistent_disk(instance_plan)

              model = Models::PersistentDisk.where(disk_cid: 'disk123').first
              expect(model.size).to eq(job_persistent_disk_size)
            end
          end

          context 'when the new disk is unmanaged' do
            let(:disk_collection) do
              collection = DeploymentPlan::PersistentDiskCollection.new(logger)
              collection.add_by_disk_name_and_type('unmanaged-disk-name', disk_type)
              collection
            end

            context 'when the old disk is unmanaged' do
              let(:disk_name) { 'unmanaged-disk-name' }

              it 'does not use cpi resize_disk' do
                disk_manager.update_persistent_disk(instance_plan)

                expect(cloud).to_not have_received(:resize_disk)
              end
            end

            context 'when the old disk is managed' do
              let(:disk_name) { '' }

              it 'does not use cpi resize_disk' do
                expect do
                  disk_manager.update_persistent_disk(instance_plan)
                end.not_to raise_error

                expect(cloud).to_not have_received(:resize_disk)
              end
            end
          end
        end

        context 'when resize_disk is not implemented' do
          it 'falls back to manually copying disk' do
            allow(cloud).to receive(:resize_disk).and_raise(Bosh::Clouds::NotImplemented)

            disk_manager.update_persistent_disk(instance_plan)

            expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123').twice
            expect(cloud).to have_received(:resize_disk)
            expect(cloud).to have_received(:create_disk).with(4096, { 'cloud' => 'properties' }, 'vm234')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'disk123')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'new-disk-cid')
          end
        end

        context 'when resize_disk is not supported' do
          let(:job_persistent_disk_size) { 3072 }

          it 'falls back to manually copying disk' do
            allow(cloud).to receive(:resize_disk).and_raise(Bosh::Clouds::NotSupported)

            disk_manager.update_persistent_disk(instance_plan)

            expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123').twice
            expect(cloud).to have_received(:resize_disk)
            expect(cloud).to have_received(:create_disk).with(3072, { 'cloud' => 'properties' }, 'vm234')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'disk123')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'new-disk-cid')
          end
        end

        context 'when shrinking disk' do
          let(:job_persistent_disk_size) { 512 }

          it 'falls back to manually copying disk' do
            disk_manager.update_persistent_disk(instance_plan)

            expect(cloud).not_to have_received(:resize_disk)
            expect(cloud).to have_received(:create_disk).with(512, { 'cloud' => 'properties' }, 'vm234')
            expect(cloud).to have_received(:attach_disk).with('vm234', 'new-disk-cid')
            expect(cloud).to have_received(:detach_disk).with('vm234', 'disk123')
          end
        end
      end

      context 'when disk creation fails' do
        context 'with NoDiskSpaceError' do
          let(:error) { Bosh::Clouds::NoDiskSpace.new(true) }

          it 'should raise the error' do
            expect(cloud).to receive(:create_disk).and_raise(error)
            expect do
              disk_manager.update_persistent_disk(instance_plan)
            end.to raise_error error
          end
        end
      end

      context 'when disk creation succeeds, but there is a NoDiskSpaceError during attach_disk' do
        let(:error) { Bosh::Clouds::NoDiskSpace.new(false) }

        it 'orphans the disk' do
          expect(cloud).to receive(:attach_disk).and_raise(error)

          expect do
            disk_manager.update_persistent_disk(instance_plan)
          end.to raise_error error
        end
      end

      context 'when the agent reports a different disk cid from the model' do
        before do
          allow(agent_client).to receive(:list_disk).and_return(['random-disk-cid'])
        end

        context 'when uuid has not been set' do
          it 'raises' do
            expect do
              disk_manager.update_persistent_disk(instance_plan)
            end.to raise_error AgentDiskOutOfSync, "'job-name/my-uuid-1 (1)' has invalid disks: agent reports 'random-disk-cid' while director record shows 'disk123'"
          end
        end

        context 'when uuid has been set' do
          let!(:instance_plan) do
            instance_model.uuid = '123-456-789'
            instance = DeploymentPlan::Instance.create_from_instance_group(instance_group, 1, 'started', deployment_model, {}, nil, logger, variables_interpolator)
            instance.bind_existing_instance_model(instance_model)

            DeploymentPlan::InstancePlan.new(existing_instance: instance_model,
                                             desired_instance: DeploymentPlan::DesiredInstance.new(instance_group),
                                             instance: instance,
                                             network_plans: [],
                                             variables_interpolator: variables_interpolator)
          end
          before do
            allow(AgentClient).to receive(:with_agent_id)
              .with(instance_model.agent_id, instance_model.name).and_return(agent_client)
          end

          it 'raises' do
            expect do
              disk_manager.update_persistent_disk(instance_plan)
            end.to raise_error AgentDiskOutOfSync, "'job-name/123-456-789 (1)' has invalid disks: agent reports 'random-disk-cid' while director record shows 'disk123'"
          end
        end
      end

      context 'when the agent reports a disk cid consistent with the model' do
        let!(:inactive_disk) do
          FactoryBot.create(:models_persistent_disk,
            disk_cid: 'inactive-disk',
            active: false,
            instance: instance_model,
            size: 54,
            cloud_properties: { 'cloud-props' => 'something' },
            cpi: 'my-cpi',
          )
        end

        it 'logs when the disks are inactive' do
          expect(logger).to receive(:warn).with("'job-name/my-uuid-1 (1)' has inactive disk inactive-disk")
          disk_manager.update_persistent_disk(instance_plan)
        end

        it 'stores events' do
          expect do
            disk_manager.update_persistent_disk(instance_plan)
          end.to change {
            Bosh::Director::Models::Event.count
          }.from(0).to(6)

          event1 = Bosh::Director::Models::Event.first
          expect(event1.user).to eq('user')
          expect(event1.action).to eq('create')
          expect(event1.object_type).to eq('disk')
          expect(event1.object_name).to eq(nil)
          expect(event1.task).to eq(task_id.to_s)
          expect(event1.deployment).to eq(instance_model.deployment.name)
          expect(event1.instance).to eq(instance_model.name)

          event2 = Bosh::Director::Models::Event.order(:id).all[1]
          expect(event2.parent_id).to eq(event1.id)
          expect(event2.user).to eq('user')
          expect(event2.action).to eq('create')
          expect(event2.object_type).to eq('disk')
          expect(event2.object_name).to eq('new-disk-cid')
          expect(event2.task).to eq(task_id.to_s)
          expect(event2.deployment).to eq(instance_model.deployment.name)
          expect(event2.instance).to eq(instance_model.name)
        end

        it 'stores events with error information' do
          allow(cloud).to receive(:create_disk).and_raise(Exception, 'error')
          expect do
            disk_manager.update_persistent_disk(instance_plan)
          end.to raise_error Exception, 'error'

          event2 = Bosh::Director::Models::Event.order(:id).all[1]
          expect(event2.error).to eq('error')
        end

        context 'when the persistent disk is changed' do
          before { expect(instance_plan.persistent_disk_changed?).to be_truthy }

          context 'when the instance group has persistent disk type and the disk type is non zero' do
            it 'calls to the cpi to create the disk specified by the job' do
              expect(cloud).to receive(:create_disk).with(1024, { 'cloud' => 'properties' }, 'vm234').and_return('new-disk-cid')
              disk_manager.update_persistent_disk(instance_plan)
            end

            it 'creates a persistent disk record' do
              disk_manager.update_persistent_disk(instance_plan)
              model = Models::PersistentDisk.where(instance_id: instance_model.id, size: 1024).first
              expect(model.cloud_properties).to eq('cloud' => 'properties')
              expect(model.cpi).to eq('my-cpi')
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
                expect do
                  disk_manager.update_persistent_disk(instance_plan)
                end.to raise_error no_space
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
                    allow(cloud).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                    allow(agent_client).to receive(:list_disk).and_return(['disk123', 'new-disk-cid'])
                  end

                  it 'switches active disks' do
                    disk_manager.update_persistent_disk(instance_plan)
                    expect(Models::PersistentDisk.where(instance_id: instance_model.id, disk_cid: 'new-disk-cid', active: true).first).to_not be_nil
                  end

                  context 'when switching active disk succeeds' do
                    let(:snapshot) { FactoryBot.create(:models_snapshot) }
                    before do
                      persistent_disk.add_snapshot(snapshot)
                      allow(agent_client).to receive(:unmount_disk).with('disk123')
                      allow(agent_client).to receive(:remove_persistent_disk).with('disk123')
                      allow(cloud).to receive(:detach_disk).with('vm234', 'disk123')
                    end

                    it 'orphans the old mounted disk' do
                      expect(agent_client).to receive(:unmount_disk).with('disk123')
                      expect(agent_client).to receive(:remove_persistent_disk).with('disk123')
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
                      expect(orphan_disk.cloud_properties).to eq('cloud-props' => 'something')
                      expect(orphan_disk.cpi).to eq('my-cpi')
                    end
                  end
                end

                context 'when mounting the disk raises' do
                  before do
                    allow(agent_client).to receive(:list_disk).and_return(['disk123'])
                    expect(agent_client).to receive(:mount_disk).with('new-disk-cid').and_raise(disk_error)
                  end

                  it 'detaches the disk and re-raises the error' do
                    expect(agent_client).to_not receive(:unmount_disk)
                    expect(agent_client).to receive(:remove_persistent_disk).with('new-disk-cid')
                    expect(cloud).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                    expect do
                      disk_manager.update_persistent_disk(instance_plan)
                    end.to raise_error disk_error
                  end
                end

                context 'when migrating the disk raises' do
                  before do
                    allow(agent_client).to receive(:list_disk).and_return(['disk123', 'new-disk-cid'])
                    expect(agent_client).to receive(:migrate_disk).with('disk123', 'new-disk-cid').and_raise(disk_error)
                  end

                  it 'deletes the disk and re-raises the error' do
                    expect(agent_client).to receive(:unmount_disk).with('new-disk-cid')
                    expect(agent_client).to receive(:remove_persistent_disk).with('new-disk-cid')
                    expect(cloud).to receive(:detach_disk).with('vm234', 'new-disk-cid')
                    expect do
                      disk_manager.update_persistent_disk(instance_plan)
                    end.to raise_error disk_error
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
          let(:disk_collection) { DeploymentPlan::PersistentDiskCollection.new(logger) }

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

          it 're-attaches the disk' do
            expect(logger).to receive(:warn).with(
              "Agent of 'job-name/my-uuid-1 (1)' reports no disk while director record shows 'disk123'. " \
              'Re-attaching existing persistent disk...',
            )
            expect(subject).to receive(:attach_disks_if_needed)

            disk_manager.update_persistent_disk(instance_plan)
          end
        end
      end

      context 'when instance has no persistent disk' do
        let(:persistent_disk) { nil }

        it 'does not raise' do
          expect do
            disk_manager.update_persistent_disk(instance_plan)
          end.not_to raise_error
        end
      end

      context 'when cloud properties has placeholders' do
        let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }

        let(:cloud_properties) do
          { 'cloud' => '((cloud_placeholder))' }
        end
        let(:interpolated_cloud_properties) do
          { 'cloud' => 'unicorns' }
        end

        let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

        before do
          allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
        end

        it 'uses the interpolated cloud config' do
          instance_plan.instance.desired_variable_set = desired_variable_set

          # Detecting if interpolated config changed for short-circuit in disk_manager, another call from checking before determining differences
          expect(variables_interpolator).to receive(:interpolated_versioned_variables_changed?).exactly(2).times
            .with(anything, anything, anything, anything)
                                                                                               .and_return(false)

          # 1 call to interpolate before we send to CPI
          expect(variables_interpolator).to receive(:interpolate_with_versioning).exactly(1).times.with(cloud_properties, desired_variable_set).and_return(interpolated_cloud_properties)

          expect(cloud).to receive(:create_disk).with(job_persistent_disk_size, interpolated_cloud_properties, instance_model.active_vm.cid).and_return('new-disk-cid')

          expect do
            disk_manager.update_persistent_disk(instance_plan)
          end.to_not raise_error
        end

        it 'does not save PersistentDisk model with the interpolated cloud config' do
          allow(variables_interpolator).to receive(:interpolate_with_versioning).with(cloud_properties, anything).and_return(interpolated_cloud_properties)
          allow(variables_interpolator).to receive(:interpolated_versioned_variables_changed?)
            .with(anything, anything, anything, anything)
            .and_return(false)
          disk_manager.update_persistent_disk(instance_plan)
          expect(Models::PersistentDisk.first.cloud_properties).to eq(cloud_properties)
        end
      end
    end

    describe '#delete_persistent_disks' do
      let(:snapshot) { FactoryBot.create(:models_snapshot, persistent_disk: persistent_disk) }
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
    end

    describe '#attach_disks_if_needed' do
      let(:cloud_for_set_disk_metadata) { instance_double(Bosh::Clouds::ExternalCpi) }

      context 'when instance desired job has disk' do
        let(:job_persistent_disk_size) { 100 }

        it 'attaches current instance disk' do
          expect(cloud).to receive(:attach_disk).with('vm234', 'disk123')
          expect(cloud_for_set_disk_metadata).to receive(:set_disk_metadata).with('disk123', hash_including(tags))
          expect(cloud_factory).to receive(:get).with(persistent_disk.cpi, nil).at_least(:once).and_return(cloud)
          expect(cloud_factory).to receive(:get).with(persistent_disk.cpi).at_least(:once).and_return(cloud_for_set_disk_metadata)
          disk_manager.attach_disks_if_needed(instance_plan)
        end
      end

      context 'when instance desired job does not have disk' do
        let(:disk_collection) { DeploymentPlan::PersistentDiskCollection.new(logger) }

        it 'does not attach current instance disk' do
          expect(cloud).to_not receive(:attach_disk)
          disk_manager.attach_disks_if_needed(instance_plan)
        end
      end
    end
  end
end
