require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater do
    let(:ip_repo) { DeploymentPlan::InMemoryIpRepo.new(logger) }
    let(:ip_provider) { DeploymentPlan::IpProvider.new(ip_repo, [], logger) }
    let(:template_blob_cache) { instance_double(Core::Templates::TemplateBlobCache) }
    let(:updater) { InstanceUpdater.new_instance_updater(ip_provider, template_blob_cache, dns_encoder) }
    let(:vm_creator) { instance_double(VmCreator) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:credentials) do
      { 'user' => 'secret' }
    end
    let(:credentials_json) { JSON.generate(credentials) }
    let(:persistent_disk_model) { instance_double(Models::PersistentDisk, name: 'some-disk', disk_cid: 'some-cid') }
    let(:disk_collection_model) do
      instance_double(DeploymentPlan::PersistentDiskCollection::ModelPersistentDisk, model: persistent_disk_model)
    end
    let(:active_persistent_disks) do
      instance_double(DeploymentPlan::PersistentDiskCollection, collection: [disk_collection_model])
    end

    let!(:ip_address) { Models::IpAddress.make(vm: instance_model.active_vm, instance: instance_model) }
    let(:instance_model) do
      instance = Models::Instance.make(
        uuid: 'uuid-1',
        deployment: deployment_model,
        state: instance_model_state,
        job: 'job-1',
        spec: { 'stemcell' => { 'name' => 'ubunut_1', 'version' => '8' } },
      )
      vm_model = Models::Vm.make(agent_id: 'scool', instance_id: instance.id)
      instance.active_vm = vm_model
      instance
    end
    let(:instance_model_state) { 'started' }
    let(:deployment_model) { Models::Deployment.make(name: 'deployment') }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:instance) do
      az = DeploymentPlan::AvailabilityZone.new('az-1', {})
      vm_type = DeploymentPlan::VmType.new('name' => 'small_vm')
      stemcell = DeploymentPlan::Stemcell.new('ubuntu_stemcell', 'ubuntu_1', 'ubuntu', '8')
      merged_cloud_properties = DeploymentPlan::MergedCloudProperties.new(az, vm_type, []).get
      instance = DeploymentPlan::Instance.new(
        'job-1',
        0,
        instance_desired_state,
        merged_cloud_properties,
        stemcell,
        {},
        false,
        deployment_model,
        {},
        az,
        logger,
        variables_interpolator,
      )
      instance.bind_existing_instance_model(instance_model)

      instance
    end
    let(:instance_desired_state) { 'stopped' }
    let(:job) { instance_double(DeploymentPlan::InstanceGroup, default_network: {}, should_create_swap_delete?: false) }
    let(:instance_plan) do
      desired_instance = DeploymentPlan::DesiredInstance.new(job)
      instance_plan = DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        instance: instance,
        desired_instance: desired_instance,
        tags: tags,
        variables_interpolator: variables_interpolator,
      )
      allow(instance_plan).to receive(:spec).and_return(DeploymentPlan::InstanceSpec.create_empty)
      allow(instance_plan).to receive(:needs_disk?).and_return(false)

      instance_plan
    end
    let(:tags) do
      { 'key1' => 'value1' }
    end
    let(:blobstore_client) { instance_double(Bosh::Blobstore::Client) }
    let(:rendered_templates_persistor) { instance_double(RenderedTemplatesPersister) }
    let(:disk_manager) { instance_double(DiskManager) }
    let(:dns_encoder) { instance_double(DnsEncoder) }
    let(:links_manager) do
      instance_double(Bosh::Director::Links::LinksManager)
    end

    before do
      Models::VariableSet.create(deployment: deployment_model)
      allow(Config).to receive_message_chain(:current_job, :username).and_return('user')
      allow(Config).to receive_message_chain(:current_job, :task_id).and_return('task-1', 'task-2')
      allow(Config).to receive_message_chain(:current_job, :event_manager).and_return(Api::EventManager.new({}))
      allow(Config).to receive(:enable_virtual_delete_vms).and_return true
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
      allow(VmCreator).to receive(:new).and_return(vm_creator)
      allow(RenderedTemplatesPersister).to receive(:new).and_return(rendered_templates_persistor)
      allow(DiskManager).to receive(:new).and_return(disk_manager)
      allow(LocalDnsEncoderManager).to receive(:new_encoder_with_updated_index).and_return(dns_encoder)
      allow(rendered_templates_persistor).to receive(:persist)
      allow(instance_model).to receive(:active_persistent_disks).and_return(active_persistent_disks)
      allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)
      allow(variables_interpolator).to receive(:interpolated_versioned_variables_changed?).and_return(false)
    end

    context 'for any state' do
      let(:state_applier) { instance_double(InstanceUpdater::StateApplier) }

      before do
        allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier)

        allow(state_applier).to receive(:apply)
        allow(instance_plan).to receive(:changes).and_return([:state])
        allow(instance_plan).to receive(:already_detached?).and_return(true)
        allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
        allow(updater).to receive(:needs_recreate?).and_return(false)
        allow(disk_manager).to receive(:update_persistent_disk)
        allow(instance).to receive(:update_instance_settings)
        allow(job).to receive(:update)
      end

      context 'when rendered templates persist fails' do
        before do
          allow(rendered_templates_persistor).to receive(:persist).and_raise('random runtime error')
        end

        it 'does NOT update the variable set id for the instance' do
          expect(instance).to_not receive(:update_variable_set)
          expect do
            updater.update(instance_plan)
          end.to raise_error
        end
      end

      it 'updates the variable_set_id on the instance' do
        expect(links_manager).to receive(:bind_links_to_instance)

        expect(instance).to receive(:update_variable_set)
        updater.update(instance_plan)
      end
    end

    context 'when stopping instances' do
      before do
        allow(AgentClient).to receive(:with_agent_id).with('scool', instance_model.name).and_return(agent_client)
        allow(instance_plan).to receive(:changes).and_return([:state])
        allow(links_manager).to receive(:bind_links_to_instance).with(instance)
      end

      context 'when instance is currently started' do
        let(:instance_model_state) { 'started' }

        it 'drains, stops, post-stops, snapshots, and persists rendered templates blobs but leaves DNS records unchanged' do
          expect(Api::SnapshotManager).to receive(:take_snapshot)
          expect(agent_client).not_to receive(:apply)
          expect(agent_client).to receive(:run_script).with('post-stop', {})
          expect(agent_client).to receive(:stop)
          expect(agent_client).to receive(:drain).and_return(0.1)
          expect(rendered_templates_persistor).to receive(:persist).with(instance_plan)

          instance_model.update(dns_record_names: ['old.dns.record'])

          updater.update(instance_plan)
          expect(instance_model.state).to eq('stopped')
          expect(instance_model.dns_record_names).to eq ['old.dns.record']
          expect(instance_model.update_completed).to eq true
          expect(Models::Event.count).to eq 2
        end
      end

      context 'when instance is currently stopped' do
        let(:instance_model_state) { 'stopped' }

        it 'does not try to post-stop, stop, drain, or snapshot' do
          expect(Api::SnapshotManager).not_to receive(:take_snapshot)
          expect(agent_client).not_to receive(:apply)
          expect(agent_client).not_to receive(:run_script).with('post-stop', {})
          expect(agent_client).not_to receive(:stop)
          expect(agent_client).not_to receive(:drain)
          allow(rendered_templates_persistor).to receive(:persist).with(instance_plan)

          updater.update(instance_plan)
          expect(instance_model.state).to eq('stopped')
          expect(instance_model.update_completed).to eq true
          expect(Models::Event.count).to eq 2
        end

        it 'persists rendered templates to the blobstore' do
          expect(rendered_templates_persistor).to receive(:persist).with(instance_plan)
          expect(links_manager).to receive(:bind_links_to_instance).with(instance)
          expect(instance).to receive(:update_variable_set)

          updater.update(instance_plan)
        end
      end

      context 'when desired instance state is detached' do
        let(:instance_model_state) { 'started' }
        let(:instance_desired_state) { 'detached' }
        let(:director_state_updater) { instance_double(DirectorDnsStateUpdater) }
        let(:unmount_step) { instance_double(DeploymentPlan::Steps::UnmountInstanceDisksStep) }
        let(:delete_step) { instance_double(DeploymentPlan::Steps::DeleteVmStep) }

        before do
          allow(DirectorDnsStateUpdater).to receive(:new).and_return(director_state_updater)
          allow(instance_plan).to receive(:dns_changed?).and_return(true)
          allow(DeploymentPlan::Steps::UnmountInstanceDisksStep).to receive(:new)
            .with(instance_model).and_return(unmount_step)
          allow(DeploymentPlan::Steps::DeleteVmStep).to receive(:new)
            .with(true, false, true).and_return delete_step
          allow(links_manager).to receive(:bind_links_to_instance)
        end

        it 'should update dns' do
          allow(instance_plan).to receive(:already_detached?).and_return(false)
          expect(instance_plan).to receive(:release_obsolete_network_plans).with(ip_provider)
          expect(unmount_step).to receive(:perform)
          expect(delete_step).to receive(:perform)
          expect(director_state_updater).to receive(:update_dns_for_instance)
            .with(instance_plan, instance_plan.network_settings.dns_record_info)

          expect(agent_client).to receive(:run_script).with('post-stop', {})
          expect(agent_client).to receive(:stop)
          expect(agent_client).to receive(:drain).and_return(0)

          updater.update(instance_plan)
          expect(instance_model.update_completed).to eq true
          expect(Models::Event.count).to eq 2
        end

        context 'if instance is already detached' do
          let(:instance_model_state) { 'detached' }

          before do
            allow(instance_plan).to receive(:already_detached?).and_return(true)
          end

          it 'binds links to detached instance' do
            allow(director_state_updater).to receive(:update_dns_for_instance)
            expect(links_manager).to receive(:bind_links_to_instance).with(instance)
            updater.update(instance_plan)
          end

          it 'still updates dns' do
            expect(director_state_updater).to receive(:update_dns_for_instance)
              .with(instance_plan, instance_plan.network_settings.dns_record_info)

            updater.update(instance_plan)
            expect(instance_model.update_completed).to eq true
            expect(Models::Event.count).to eq 2
          end
        end
      end
    end

    context 'when starting instances' do
      let(:instance_desired_state) { 'started' }

      before do
        allow(AgentClient).to receive(:with_agent_id).with('scool', instance_model.name).and_return(agent_client)
        allow(instance_plan).to receive(:changes).and_return([:state])
      end

      context 'when instance is currently stopped' do
        let(:instance_model_state) { 'stopped' }
        let(:disk_manager) { instance_double(DiskManager) }
        let(:state_applier) { instance_double(InstanceUpdater::StateApplier) }
        let(:unmount_step) { instance_double(DeploymentPlan::Steps::UnmountInstanceDisksStep, perform: nil) }
        let(:detach_step) { instance_double(DeploymentPlan::Steps::DetachInstanceDisksStep, perform: nil) }

        before do
          allow(DiskManager).to receive(:new).and_return(disk_manager)
          allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier)
          allow(DeploymentPlan::Steps::UnmountInstanceDisksStep).to receive(:new)
            .with(instance_model).and_return(unmount_step)
          allow(DeploymentPlan::Steps::DetachInstanceDisksStep).to receive(:new)
            .with(instance_model).and_return(detach_step)

          allow(updater).to receive(:needs_recreate?).and_return(false)
          allow(disk_manager).to receive(:update_persistent_disk)
          allow(job).to receive(:update)
          allow(instance).to receive(:update_instance_settings)

          expect(instance_plan).to receive(:release_obsolete_network_plans).with(ip_provider)
        end

        it 'does NOT drain, stop, post-stop, snapshot, but persists rendered templates to the blobstore, updates DNS and bind links' do
          # https://www.pivotaltracker.com/story/show/121721619
          expect(Api::SnapshotManager).to_not receive(:take_snapshot)
          expect(agent_client).to_not receive(:run_script).with('post-stop', {})
          expect(agent_client).to_not receive(:stop)
          expect(agent_client).to_not receive(:drain)

          expect(state_applier).to receive(:apply)
          expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice
          expect(links_manager).to receive(:bind_links_to_instance).with(instance)

          subnet_spec = {
            'range' => '10.10.10.0/24',
            'gateway' => '10.10.10.1',
          }
          subnet = DeploymentPlan::ManualNetworkSubnet.parse('my-network', subnet_spec, ['az-1'], [])
          network = DeploymentPlan::ManualNetwork.new('my-network', [subnet], logger)
          reservation = ExistingNetworkReservation.new(instance_model, network, '10.10.10.10', :dynamic)
          instance_plan.network_plans = [
            DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation, existing: true),
          ]

          instance_model.update(dns_record_names: ['old.dns.record'])

          updater.update(instance_plan)

          expect(instance_model.update_completed).to eq true
          expect(instance_model.dns_record_names).to eq [
            'old.dns.record',
            '0.job-1.my-network.deployment.bosh',
            'uuid-1.job-1.my-network.deployment.bosh',
          ]
          expect(Models::Event.count).to eq 2
          expect(Models::Event.all[1].error).to be_nil
        end

        context 'when an instance needs to be recreated' do
          let(:delete_step) { instance_double(DeploymentPlan::Steps::DeleteVmStep) }

          before do
            allow(updater).to receive(:needs_recreate?).and_return(true)
            allow(disk_manager).to receive(:update_persistent_disk)
            allow(job).to receive(:update)
            allow(DeploymentPlan::Steps::DeleteVmStep).to receive(:new)
              .with(true, false, true).and_return delete_step
          end

          it 'recreates correctly, and persists rendered templates to the blobstore' do
            expect(unmount_step).to receive(:perform)
            expect(detach_step).to receive(:perform)
            expect(delete_step).to receive(:perform) do |report|
              expect(report.vm).to eql(instance_model.active_vm)
            end
            expect(vm_creator).to receive(:create_for_instance_plan) do |i, ipp, disks, tags, use_existing|
              expect(instance_plan).to eq(i)
              expect(ipp).to eq(ip_provider)
              expect(disks).to eq([persistent_disk_model.disk_cid])
              expect(tags).to eq(tags)
              expect(use_existing).to eq(nil)
            end

            expect(state_applier).to receive(:apply)
            expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice
            expect(links_manager).to receive(:bind_links_to_instance).with(instance)

            updater.update(instance_plan)
          end

          context 'and has unresponsive agent' do
            before do
              allow(instance_plan).to receive(:unresponsive_agent?).and_return(true)
            end

            it 'does not unmount and detach disk, then recreates correctly and persists rendered templates to blobstore' do
              expect(unmount_step).not_to receive(:perform)
              expect(detach_step).not_to receive(:perform)
              expect(delete_step).to receive(:perform) do |report|
                expect(report.vm).to eql(instance_model.active_vm)
              end
              expect(vm_creator).to receive(:create_for_instance_plan) do |i, ipp, disks, tags, use_existing|
                expect(instance_plan).to eq(i)
                expect(ipp).to eq(ip_provider)
                expect(disks).to eq([persistent_disk_model.disk_cid])
                expect(tags).to eq(tags)
                expect(use_existing).to eq(nil)
              end

              expect(state_applier).to receive(:apply)
              expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice
              expect(links_manager).to receive(:bind_links_to_instance).with(instance)

              updater.update(instance_plan)
            end
          end

          context 'when the instance uses create-swap-delete strategy' do
            let(:elect_active_vm_step) { instance_double(DeploymentPlan::Steps::ElectActiveVmStep, perform: nil) }
            let!(:inactive_vm_model) { Models::Vm.make(instance_id: instance_model.id) }
            let(:attach_step) { instance_double(DeploymentPlan::Steps::AttachInstanceDisksStep, perform: nil) }
            let(:mount_step) { instance_double(DeploymentPlan::Steps::MountInstanceDisksStep, perform: nil) }
            let(:apply_spec_step) { instance_double(DeploymentPlan::Steps::ApplyVmSpecStep, perform: nil) }
            let(:orphan_vm_step) { instance_double(DeploymentPlan::Steps::OrphanVmStep, perform: nil) }

            before do
              allow(instance_plan).to receive(:should_create_swap_delete?).and_return(true)
              allow(DeploymentPlan::Steps::ElectActiveVmStep).to receive(:new)
                .and_return(elect_active_vm_step)
              allow(DeploymentPlan::Steps::AttachInstanceDisksStep).to receive(:new)
                .with(instance_model, 'key1' => 'value1').and_return(attach_step)
              allow(DeploymentPlan::Steps::MountInstanceDisksStep).to receive(:new)
                .with(instance_model).and_return(mount_step)
              allow(DeploymentPlan::Steps::ApplyVmSpecStep).to receive(:new)
                .with(instance_plan).and_return(apply_spec_step)
              allow(DeploymentPlan::Steps::OrphanVmStep).to receive(:new)
                .with(instance_model.active_vm).and_return(orphan_vm_step)
              allow(links_manager).to receive(:bind_links_to_instance).with(instance)

              allow(state_applier).to receive(:apply)
            end

            it 'activates the vm but does not delete the old one or create another vm' do
              expect(unmount_step).to receive(:perform)
              expect(detach_step).to receive(:perform)
              expect(DeploymentPlan::Steps::DeleteVmStep).to_not receive(:new)
              expect(vm_creator).not_to receive(:create_for_instance_plan)

              expect(instance_model).to receive(:most_recent_inactive_vm).and_return(inactive_vm_model)
              expect(elect_active_vm_step).to receive(:perform)
              expect(state_applier).to receive(:apply)
              expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice

              updater.update(instance_plan)
            end

            it 'orphans the old vm after activating the new one' do
              expect(elect_active_vm_step).to receive(:perform)
              expect(orphan_vm_step).to receive(:perform)

              expected_ips = instance_model.active_vm.ip_addresses.map(&:address_str)
              expect(instance_plan).to receive(:remove_obsolete_network_plans_for_ips).with(expected_ips)

              updater.update(instance_plan)
            end

            context 'and has unresponsive agent' do
              before do
                allow(instance_plan).to receive(:unresponsive_agent?).and_return(true)
              end

              it 'deletes the old vm and does NOT try to orphan it' do
                expect(unmount_step).not_to receive(:perform)
                expect(detach_step).not_to receive(:perform)
                expect(delete_step).to receive(:perform) do |report|
                  expect(report.vm).to eql(instance_model.active_vm)
                end
                expect(vm_creator).not_to receive(:create_for_instance_plan)

                expect(instance_model).to receive(:most_recent_inactive_vm).and_return(inactive_vm_model)
                expect(elect_active_vm_step).to receive(:perform)
                expect(orphan_vm_step).not_to receive(:perform)
                expect(state_applier).to receive(:apply)
                expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice

                updater.update(instance_plan)
              end
            end

            context 'and has only one VM, which is currently active' do
              before do
                inactive_vm_model.destroy
              end

              it 'does NOT orphan the active VM and synchrously recreates the vm' do
                expect(elect_active_vm_step).not_to receive(:perform)
                expect(orphan_vm_step).not_to receive(:perform)
                expect(delete_step).to receive(:perform) do |report|
                  expect(report.vm).to eql(instance_model.active_vm)
                end
                expect(vm_creator).to receive(:create_for_instance_plan)
                expect(instance_model).to receive(:most_recent_inactive_vm).and_return(inactive_vm_model)
                expect(state_applier).to receive(:apply)
                expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice

                updater.update(instance_plan)
              end
            end

            context 'when instance has persistent disks' do
              before do
                allow(instance_plan).to receive(:needs_disk?).and_return(true)
              end

              it 'attaches and mounts persistent disks' do
                expect(attach_step).to receive(:perform)
                expect(mount_step).to receive(:perform)
                expect(state_applier).to receive(:apply)
                expect(links_manager).to receive(:bind_links_to_instance).with(instance)

                updater.update(instance_plan)
              end
            end
          end
        end
      end
    end

    context 'when changing DNS' do
      before do
        allow(instance_plan).to receive(:changes).and_return([:dns])
      end

      it 'exits early without interacting with the agent, and does NOT persist rendered templates to the blobstore' do
        instance_model.update(dns_record_names: ['old.dns.record'])
        expect(instance_model.state).to eq('started')
        expect(Models::Event.count).to eq 0

        expect(AgentClient).not_to receive(:with_agent_id)

        subnet_spec = {
          'range' => '10.10.10.0/24',
          'gateway' => '10.10.10.1',
        }
        subnet = DeploymentPlan::ManualNetworkSubnet.parse('my-network', subnet_spec, ['az-1'], [])
        network = DeploymentPlan::ManualNetwork.new('my-network', [subnet], logger)
        reservation = ExistingNetworkReservation.new(instance_model, network, '10.10.10.10', :dynamic)
        instance_plan.network_plans = [
          DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation, existing: true),
        ]

        expect do
          updater.update(instance_plan)
        end.not_to(change { Models::RenderedTemplatesArchive.count })

        expect(instance_model.dns_record_names).to eq [
          'old.dns.record',
          '0.job-1.my-network.deployment.bosh',
          'uuid-1.job-1.my-network.deployment.bosh',
        ]
        expect(instance_model.update_completed).to eq true
        expect(Models::Event.count).to eq 2
      end
    end

    context 'when the VM does not get recreated' do
      let(:disk_manager) { instance_double(DiskManager) }
      let(:state_applier) { instance_double(InstanceUpdater::StateApplier) }

      before do
        allow(DiskManager).to receive(:new).and_return(disk_manager)
        allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier)

        expect(instance_plan).to receive(:release_obsolete_network_plans).with(ip_provider)
      end

      it 'updates the instance settings and bind links' do
        allow(instance_plan).to receive(:changes).and_return([:trusted_certs])
        allow(AgentClient).to receive(:with_agent_id).with('scool', instance_model.name).and_return(agent_client)

        allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)

        allow(instance_plan).to receive(:already_detached?).and_return(true)
        allow(disk_manager).to receive(:update_persistent_disk)
        allow(state_applier).to receive(:apply)
        allow(job).to receive(:update)
        allow(rendered_templates_persistor).to receive(:persist).with(instance_plan)

        allow(logger).to receive(:debug)

        expect(links_manager).to receive(:bind_links_to_instance).with(instance)
        expect(instance).to receive(:update_instance_settings)
        updater.update(instance_plan)
      end
    end

    context 'when something goes wrong in the update procedure' do
      before do
        allow(AgentClient).to receive(:with_agent_id).with('scool', instance_model.name).and_return(agent_client)
        allow(instance_plan).to receive(:changes).and_return([:state])
        allow(rendered_templates_persistor).to receive(:persist)
        allow(links_manager).to receive(:bind_links_to_instance).with(instance)
      end

      it 'should always add an event recording the error' do
        expect(Models::Event.count).to eq 0

        drain_error = RpcRemoteException.new('Oh noes!')
        expect(agent_client).to receive(:drain).and_raise(drain_error)

        expect { updater.update(instance_plan) }.to raise_error drain_error
        expect(Models::Event.map(&:error)).to match_array([nil, 'Oh noes!'])
      end
    end
  end
end
