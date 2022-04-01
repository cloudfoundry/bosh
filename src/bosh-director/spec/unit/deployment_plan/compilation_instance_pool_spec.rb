require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe DeploymentPlan::CompilationInstancePool do
    subject(:compilation_instance_pool) do
      DeploymentPlan::CompilationInstancePool.new(
        instance_reuser,
        instance_provider,
        logger,
        instance_deleter,
        double(:config, workers: max_instance_count, orphan_workers: orphan_workers),
      )
    end

    let(:agent_broadcaster) { AgentBroadcaster.new }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:another_agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:availability_zone) { nil }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_wrapper) { Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud, 1) }
    let(:package) { instance_double(Models::Package, name: 'fake-package') }
    let(:package2) { instance_double(Models::Package, name: 'fake-package2') }

    let(:cloud_properties) { { 'cloud' => 'properties' } }
    let(:create_instance_error) { RuntimeError.new('failed to create instance') }
    let(:deployment_model) { Models::Deployment.make(name: 'mycloud') }
    let(:dns_encoder) { DnsEncoder.new }
    let(:event_manager) { Api::EventManager.new(true) }
    let(:expected_network_settings) { { 'a' => { 'a' => { 'property' => 'settings' } } } }
    let(:instance_deleter) { instance_double(Bosh::Director::InstanceDeleter) }
    let(:instance_provider) { DeploymentPlan::InstanceProvider.new(deployment_plan, vm_creator, logger) }
    let(:instance_reuser) { InstanceReuser.new }
    let(:ip_provider) { instance_double(DeploymentPlan::IpProvider, reserve: nil, release: nil) }
    let(:max_instance_count) { 1 }
    let(:n_workers) { 3 }
    let(:network_settings) { { 'a' => { 'property' => 'settings' } } }
    let(:orphan_workers) { false }
    let(:tags) { { 'tag1' => 'value1' } }
    let(:task_id) { 42 }
    let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
    let(:trusted_certs) { "Trust me. I know what I'm doing." }
    let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
    let(:vm_creator) do
      VmCreator.new(Config.logger, template_blob_cache, dns_encoder, agent_broadcaster, deployment_plan.link_provider_intents)
    end
    let(:vm_deleter) { VmDeleter.new(Config.logger, false, false) }
    let(:vm_resources_cache) { instance_double(Bosh::Director::DeploymentPlan::VmResourcesCache) }
    let(:metadata_updater) { instance_double(MetadataUpdater) }

    let(:update_job) do
      instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager)
    end

    let(:subnet) do
      instance_double('Bosh::Director::DeploymentPlan::ManualNetworkSubnet', range: NetAddr::IPv4Net.parse('192.168.0.0/24'))
    end

    let(:stemcell) do
      model = Models::Stemcell.make(cid: 'stemcell-cid', name: 'stemcell-name')
      stemcell = DeploymentPlan::Stemcell.make(name: model.name, version: model.version)
      stemcell.bind_model(deployment_model)
      stemcell
    end

    let(:another_stemcell) do
      model = Models::Stemcell.make(cid: 'another-stemcell-cid', name: 'stemcell-name')
      stemcell = DeploymentPlan::Stemcell.make(name: model.name, version: model.version)
      stemcell.bind_model(deployment_model)
      stemcell
    end

    let(:different_stemcell) do
      model = Models::Stemcell.make(cid: 'different-stemcell-cid', name: 'different-stemcell-name')
      stemcell = DeploymentPlan::Stemcell.make(name: model.name, version: model.version)
      stemcell.bind_model(deployment_model)
      stemcell
    end

    let(:compilation_config) do
      compilation_spec = {
        'workers' => n_workers,
        'network' => 'a',
        'env' => compilation_env,
        'cloud_properties' => cloud_properties,
        'reuse_compilation_vms' => false,
        'az' => '',
      }
      DeploymentPlan::CompilationConfig.new(compilation_spec, {}, [])
    end

    let(:deployment_plan) do
      instance_double(
        Bosh::Director::DeploymentPlan::Planner,
        compilation: compilation_config,
        model: deployment_model,
        name: 'mycloud',
        ip_provider: ip_provider,
        recreate: false,
        template_blob_cache: template_blob_cache,
        use_short_dns_addresses?: false,
        use_link_dns_names?: false,
        tags: tags,
        vm_resources_cache: vm_resources_cache,
        link_provider_intents: [],
      )
    end

    let(:network) do
      instance_double('Bosh::Director::DeploymentPlan::ManualNetwork', name: 'a', subnets: [subnet])
    end

    let(:expected_groups) do
      [
        'fake-director-name',
        'mycloud',
        'compilation-deadbeef',
        'fake-director-name-mycloud',
        'mycloud-compilation-deadbeef',
        'fake-director-name-mycloud-compilation-deadbeef',
      ]
    end

    let(:compilation_env) do
      {
        'compilation' => 'environment',
        'bosh' => {
          'group' => 'fake-director-name-mycloud-compilation-deadbeef',
          'groups' => expected_groups,
          'tags' => tags,
        },
      }
    end

    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
      allow(thread_pool).to receive(:process).and_yield
      allow(thread_pool).to receive(:working?).and_return(false)
      thread_pool
    end

    before do
      allow(Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(cloud).to receive(:create_vm)
      allow(cloud).to receive(:set_vm_metadata)
      allow(cloud).to receive(:info).and_return({})
      allow(cloud).to receive(:request_cpi_api_version=).with(1)
      allow(cloud).to receive(:request_cpi_api_version).and_return(1)
      allow(Config).to receive(:preferred_cpi_api_version).and_return(1)
      allow(Bosh::Clouds::ExternalCpi).to receive(:new).and_return(cloud)
      allow(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).with(cloud, anything).and_return(cloud_wrapper)
      allow(network).to receive(:network_settings)
        .with(instance_of(DesiredNetworkReservation), %w[dns gateway], availability_zone).and_return(network_settings)
      allow(Config).to receive(:trusted_certs).and_return(trusted_certs)
      allow(Config).to receive(:name).and_return('fake-director-name')
      allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
      allow(agent_client).to receive(:wait_until_ready)
      allow(agent_client).to receive(:update_settings)
      allow(agent_client).to receive(:get_state)
      allow(agent_client).to receive(:apply)
      allow(another_agent_client).to receive(:wait_until_ready)
      allow(another_agent_client).to receive(:update_settings)
      allow(another_agent_client).to receive(:get_state)
      allow(another_agent_client).to receive(:apply)
      allow(ThreadPool).to receive_messages(new: thread_pool)
      allow(deployment_plan).to receive(:network).with('a').and_return(network)
      allow(instance_deleter).to receive(:delete_instance_plan)
      allow(Config).to receive(:current_job).and_return(update_job)
      allow(deployment_model).to receive(:current_variable_set).and_return(Models::VariableSet.make)
      allow(MetadataUpdater).to receive(:new).and_return(metadata_updater)
      allow(metadata_updater).to receive(:update_vm_metadata)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(blobstore).to receive(:can_sign_urls?).and_return(false)
      allow(blobstore).to receive(:validate!)
    end

    shared_examples_for 'a compilation vm pool' do
      it 'reserves a network for a new vm' do
        expect(ip_provider).to receive(:reserve) do |reservation|
          expect(reservation.dynamic?).to be_truthy
        end

        action
      end

      it 'defers to the vm creator to create a vm' do
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1', 'agent-id')
        expect(cloud).to receive(:create_vm).with(
          'agent-id',
          stemcell.models.first.cid,
          cloud_properties,
          expected_network_settings,
          [],
          compilation_env,
        )
        action
      end

      it 'applies initial vm state' do
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1')
        expected_apply_spec = {
          'deployment' => 'mycloud',
          'job' => {
            'name' => 'compilation-deadbeef',
          },
          'index' => 0,
          'id' => 'instance-uuid-1',
          'networks' => expected_network_settings,
        }
        expect(agent_client).to receive(:apply).with(expected_apply_spec)

        action

        compilation_instance = Models::Instance.find(uuid: 'instance-uuid-1')
        expect(compilation_instance.active_vm.trusted_certs_sha1).to eq(::Digest::SHA1.hexdigest(trusted_certs))
      end

      it 'passes tags to vm' do
        expect(metadata_updater).to receive(:update_vm_metadata).with(anything, anything, tags.merge(compiling: package.name))
        action
      end

      it 'should record creation event' do
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1')
        expect do
          action
        end.to change { Bosh::Director::Models::Event.count }.from(0).to(4)

        event1 = Bosh::Director::Models::Event.order(:id).first
        expect(event1.user).to eq('user')
        expect(event1.action).to eq('create')
        expect(event1.object_type).to eq('instance')
        expect(event1.object_name).to eq('compilation-deadbeef/instance-uuid-1')
        expect(event1.task).to eq(task_id.to_s)
        expect(event1.deployment).to eq('mycloud')
        expect(event1.instance).to eq('compilation-deadbeef/instance-uuid-1')

        event2 = Bosh::Director::Models::Event.order(:id).last
        expect(event2.parent_id).to eq(event1.id)
        expect(event2.user).to eq('user')
        expect(event2.action).to eq('create')
        expect(event2.object_type).to eq('instance')
        expect(event2.object_name).to eq('compilation-deadbeef/instance-uuid-1')
        expect(event2.task).to eq(task_id.to_s)
        expect(event2.deployment).to eq('mycloud')
        expect(event2.instance).to eq('compilation-deadbeef/instance-uuid-1')
      end

      context 'when vm_resources are given' do
        let(:compilation_config) do
          compilation_spec = {
            'workers' => n_workers,
            'network' => 'a',
            'vm_resources' => {
              'cpu' => 4,
              'ram' => 2048,
              'ephemeral_disk_size' => 100,
            },
          }

          DeploymentPlan::CompilationConfig.new(compilation_spec, {}, [])
        end

        it 'retrieves the vm requirements from the CPI/cache and populates the cloud properties' do
          allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1', 'agent-id')
          allow(deployment_plan.vm_resources_cache).to receive(:get_vm_cloud_properties)
            .with(nil, 'cpu' => 4, 'ram' => 2048, 'ephemeral_disk_size' => 100)
            .and_return('vm_resources' => 'foo')

          allow(cloud).to receive(:create_vm) do |_, _, cloud_properties|
            expect(cloud_properties['vm_resources']).to eq('foo')
          end

          action
        end
      end

      context 'when instance creation fails' do
        context 'when keep_unreachable_vms is set' do
          before { Config.keep_unreachable_vms = true }

          it 'does not delete instance' do
            expect { action_that_raises }.to raise_error(create_instance_error)
            expect(instance_deleter).to_not have_received(:delete_instance_plan)
          end
        end

        context 'when keep_unreachable_vms is not set' do
          it 'deletes the instance' do
            expect { action_that_raises }.to raise_error(create_instance_error)
            expect(instance_deleter).to have_received(:delete_instance_plan)
          end

          it 'should record creation event with error' do
            expect do
              action_that_raises
            end.to raise_error RuntimeError
            event2 = Bosh::Director::Models::Event.order(:id).last
            expect(event2.error).to eq('failed to create instance')
          end
        end
      end
    end

    describe 'with_reused_vm' do
      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_reused_vm(stemcell, package) {} }

        let(:action_that_raises) do
          allow(vm_creator).to receive(:create_for_instance_plan).and_raise(create_instance_error)
          compilation_instance_pool.with_reused_vm(stemcell, package)
        end
      end

      context 'when the the pool is full' do
        context 'and there are no available instances for the given stemcell' do
          it 'destroys the idle instance made for a different stemcell' do
            compilation_instance_pool.with_reused_vm(stemcell, package) { |i| }
            expect(instance_deleter).to_not have_received(:delete_instance_plan)
            expect(instance_reuser.get_num_instances(stemcell)).to eq(1)

            compilation_instance_pool.with_reused_vm(different_stemcell, package) { |i| }

            expect(instance_reuser.get_num_instances(stemcell)).to eq(0)
            expect(instance_reuser.get_num_instances(different_stemcell)).to eq(1)
            expect(instance_deleter).to have_received(:delete_instance_plan)
          end
        end
      end

      context 'after a vm is created' do
        it 'is reused' do
          original = nil
          expect(metadata_updater).to receive(:update_vm_metadata).with(
            anything,
            anything,
            tags.merge(compiling: package.name),
          )
          compilation_instance_pool.with_reused_vm(stemcell, package) do |instance|
            original = instance
          end

          reused = nil
          expect(metadata_updater).to receive(:update_vm_metadata).with(
            anything,
            anything,
            tags.merge(compiling: package2.name),
          )
          compilation_instance_pool.with_reused_vm(stemcell, package2) do |instance|
            reused = instance
          end
          expect(reused).to be(original)
        end
      end

      context 'when az is specified' do
        let(:compilation_config) do
          compilation_spec = {
            'workers' => n_workers,
            'network' => 'a',
            'env' => compilation_env,
            'cloud_properties' => cloud_properties,
            'reuse_compilation_vms' => false,
            'az' => 'foo-az',
          }
          DeploymentPlan::CompilationConfig.new(compilation_spec, { 'foo-az' => availability_zone }, [])
        end

        let(:max_instance_count) { 4 }

        let(:availability_zone) { DeploymentPlan::AvailabilityZone.new('foo-az', cloud_properties) }

        let(:deployment_model) { Models::Deployment.make(name: 'mycloud', cloud_config: cloud_config) }
        let(:deployment_model) do
          deployment = Models::Deployment.make(name: 'mycloud')
          deployment.cloud_configs = [cloud_config]
          deployment
        end
        let(:cloud_config) do
          Models::Config.make(
            :cloud,
            raw_manifest: Bosh::Spec::Deployments.simple_cloud_config.merge(
              'azs' => [{ 'name' => 'foo-az' }],
            ),
          )
        end
        let(:vm_creator) { instance_double('Bosh::Director::VmCreator') }

        before do
          expect(vm_creator).to receive(:create_for_instance_plan) do |instance_plan, ipp, disks, tags, use_existing|
            expect(instance_plan.network_settings_hash).to eq('a' => { 'a' => { 'property' => 'settings' } })
            expect(instance_plan.instance.cloud_properties).to eq('cloud' => 'properties')
            expect(instance_plan.instance.env).to eq(
              'compilation' => 'environment',
              'bosh' =>
                {
                  'group' => 'fake-director-name-mycloud-compilation-deadbeef',
                  'groups' => [
                    'fake-director-name',
                    'mycloud',
                    'compilation-deadbeef',
                    'fake-director-name-mycloud',
                    'mycloud-compilation-deadbeef',
                    'fake-director-name-mycloud-compilation-deadbeef',
                  ],
                  'tags' => tags,
                },
            )
            expect(ipp).to eq(ip_provider)
            expect(disks).to eq([])
            expect(tags).to eq('tag1' => 'value1')
            expect(use_existing).to eq(nil)
          end

          allow(VmCreator).to receive(:new)
            .with(logger, vm_deleter, template_blob_cache, agent_broadcaster, deployment_plan.link_provider_intents)
            .and_return(vm_creator)
        end

        it 'spins up vm in the az' do
          vm_instance = nil
          compilation_instance_pool.with_reused_vm(stemcell, package) do |instance|
            vm_instance = instance
          end
          expect(vm_instance.availability_zone_name).to eq('foo-az')
        end

        it 'saves az name in database' do
          allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1')
          compilation_instance_pool.with_reused_vm(stemcell, package) {}

          expect(Models::Instance.find(uuid: 'instance-uuid-1').availability_zone).to eq('foo-az')
        end
      end

      context 'when vm_type is specified' do
        let(:compilation_config) do
          compilation_spec = {
            'workers' => n_workers,
            'network' => 'a',
            'vm_type' => 'type-a',
          }
          vm_type_spec = {
            'name' => 'type-a',
            'cloud_properties' => {
              'instance_type' => 'big',
            },
          }
          DeploymentPlan::CompilationConfig.new(compilation_spec, {}, [DeploymentPlan::VmType.new(vm_type_spec)])
        end

        let(:max_instance_count) { 4 }

        it 'spins up vm with the correct VM type' do
          expect(cloud).to receive(:create_vm).with(
            anything,
            anything,
            { 'instance_type' => 'big' },
            anything,
            anything,
            anything,
          )

          compilation_instance_pool.with_reused_vm(stemcell, package) {}
        end
      end

      context 'when vm raises an Rpc timeout error' do
        it 'removes the vm from the reuser' do
          expect(instance_reuser).to receive(:remove_instance)
          expect do
            compilation_instance_pool.with_reused_vm(stemcell, package) { raise create_instance_error }
          end.to raise_error(create_instance_error)
        end

        context 'when keep_unreachable_vms is set' do
          before { Config.keep_unreachable_vms = true }

          it 'removes the vm from the reuser so that it is not cleaned up later when reuser deletes all instances' do
            expect(instance_reuser).to receive(:remove_instance)
            expect do
              compilation_instance_pool.with_reused_vm(stemcell, package) { raise create_instance_error }
            end.to raise_error(create_instance_error)
          end
        end
      end

      context 'when vm raises an Rpc timeout error' do
        it 'no longer offers that vm for reuse' do
          original = nil
          compilation_instance_pool.with_reused_vm(stemcell, package) do |instance|
            original = instance
          end

          expect do
            compilation_instance_pool.with_reused_vm(stemcell, package) { raise create_instance_error }
          end.to raise_error(create_instance_error)

          different = nil
          compilation_instance_pool.with_reused_vm(stemcell, package) do |instance|
            different = instance
          end
          expect(different).to_not eq(original)
        end
      end

      describe 'delete_instances' do
        let(:max_instance_count) { 2 }

        before do
          compilation_instance_pool.with_reused_vm(stemcell, package) {}
          compilation_instance_pool.with_reused_vm(another_stemcell, package) {}
        end

        it 'removes the vm from the reuser' do
          expect(instance_reuser.get_num_instances(stemcell)).to eq(1)
          compilation_instance_pool.delete_instances(max_instance_count)
          expect(instance_reuser.get_num_instances(stemcell)).to eq(0)
        end

        it 'deletes the instance' do
          compilation_instance_pool.delete_instances(max_instance_count)
          expect(instance_deleter).to have_received(:delete_instance_plan).exactly(2).times
        end
      end

      context 'orphan workers is enabled' do
        let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan) }
        let(:orphan_step) { instance_double(DeploymentPlan::Steps::OrphanVmStep) }
        let(:orphan_workers) { true }

        before do
          compilation_instance_pool.with_reused_vm(stemcell, package) {}
        end

        it 'orphans the vm' do
          compilation_instance = Models::Instance.find(deployment_id: deployment_model.id)
          expect(compilation_instance.active_vm).to_not be_nil

          allow(instance_plan).to receive(:instance_model).and_return(compilation_instance)
          expect(instance_plan).to receive(:release_all_network_plans)
          allow(DeploymentPlan::InstancePlan).to receive(:new).and_return(instance_plan)

          allow(DeploymentPlan::Steps::OrphanVmStep).to receive(:new).with(compilation_instance.active_vm).and_return(orphan_step)
          expect(orphan_step).to receive(:perform)

          compilation_instance_pool.delete_instances(max_instance_count)
          expect(instance_deleter).to have_received(:delete_instance_plan).exactly(1).times
        end
      end
    end

    describe 'with_single_use_vm' do
      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_single_use_vm(stemcell, package) {} }

        let(:action_that_raises) do
          allow(vm_creator).to receive(:create_for_instance_plan).and_raise(create_instance_error)
          compilation_instance_pool.with_single_use_vm(stemcell, package)
        end
      end

      context 'orphan workers is enabled' do
        let(:instance) { instance_double(Models::Instance, active_vm: vm) }
        let(:instance_memo) { instance_double(DeploymentPlan::InstanceMemo) }
        let(:deployment_instance) { instance_double(DeploymentPlan::Instance, model: instance) }
        let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: deployment_instance) }
        let(:orphan_step) { instance_double(DeploymentPlan::Steps::OrphanVmStep) }
        let(:orphan_workers) { true }
        let(:vm) { instance_double(Models::Vm) }

        it 'orphans the vm' do
          allow(instance).to receive(:vms).and_return([vm])
          allow(instance_plan).to receive(:instance_model).and_return(instance)
          expect(instance_plan).to receive(:release_all_network_plans)

          allow(DeploymentPlan::InstanceMemo).to receive(:new).and_return(instance_memo)
          allow(instance_memo).to receive(:instance_plan).and_return(instance_plan)
          allow(instance_memo).to receive(:instance).and_return(deployment_instance)

          allow(DeploymentPlan::Steps::OrphanVmStep).to receive(:new).with(vm).and_return(orphan_step)
          expect(orphan_step).to receive(:perform)
          compilation_instance_pool.with_single_use_vm(stemcell, package) {}
          expect(instance_deleter).to have_received(:delete_instance_plan).exactly(1).times
        end
      end
    end

    describe '.create' do
      let(:instance_reuser) { InstanceReuser.new }
      let(:disk_manager) { DiskManager.new(logger) }
      let(:agent_broadcaster) { AgentBroadcaster.new }
      let(:powerdns_manager) { PowerDnsManagerProvider.create }
      let(:vm_deleter) { instance_double('Bosh::Director::VmDeleter') }
      let(:vm_creator) { instance_double('Bosh::Director::VmCreator') }
      let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }
      let(:instance_provider) { instance_double('Bosh::Director::DeploymentPlan::InstanceProvider') }

      before do
        allow(AgentBroadcaster).to receive(:new).and_return(agent_broadcaster)
        allow(Config).to receive(:enable_virtual_delete_vms).and_return(false)
        allow(Config).to receive(:logger).and_return(logger)
        allow(DiskManager).to receive(:new).with(logger).and_return(disk_manager)
        allow(InstanceDeleter).to receive(:new).with(powerdns_manager, disk_manager).and_return(instance_deleter)
        allow(InstanceReuser).to receive(:new).and_return(instance_reuser)
        allow(PowerDnsManagerProvider).to receive(:create).and_return(powerdns_manager)
        allow(VmCreator).to receive(:new)
          .with(logger, template_blob_cache, anything, agent_broadcaster, deployment_plan.link_provider_intents)
          .and_return(vm_creator)
        allow(VmDeleter).to receive(:new).with(logger, false, false).and_return(vm_deleter)

        allow(DeploymentPlan::InstanceProvider).to receive(:new)
          .with(deployment_plan, vm_creator, logger)
          .and_return(instance_provider)
        allow(deployment_plan).to receive(:availability_zones).and_return([])

        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
      end

      it 'creates the needed collaborators and news up a CompilationInstancePool' do
        expect(DeploymentPlan::CompilationInstancePool).to receive(:new).with(
          instance_reuser,
          instance_provider,
          logger,
          instance_deleter,
          compilation_config,
        ).and_call_original

        DeploymentPlan::CompilationInstancePool.create(deployment_plan)
      end
    end
  end

  describe DeploymentPlan::CompilationInstanceGroup do
    it "has no 'lifecycle'" do
      expect(DeploymentPlan::CompilationInstanceGroup.new(nil, nil, nil, nil, nil, nil, nil).lifecycle).to be_nil
    end
  end
end
