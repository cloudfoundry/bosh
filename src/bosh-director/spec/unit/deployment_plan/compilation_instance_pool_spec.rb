require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe DeploymentPlan::CompilationInstancePool do
    subject(:compilation_instance_pool) { DeploymentPlan::CompilationInstancePool.new(instance_reuser, instance_provider, logger, instance_deleter, max_instance_count) }

    let(:instance_reuser) { InstanceReuser.new }
    let(:cloud) { Config.cloud }

    let(:instance_provider) { DeploymentPlan::InstanceProvider.new(deployment_plan, vm_creator, logger) }
    let(:stemcell) do
      model = Models::Stemcell.make(cid: 'stemcell-cid', name: 'stemcell-name')
      stemcell = DeploymentPlan::Stemcell.new('stemcell-name-alias', 'stemcell-name', nil, model.version)
      stemcell.bind_model(deployment_model)
      stemcell
    end

    let(:another_stemcell) do
      model = Models::Stemcell.make(cid: 'another-stemcell-cid', name: 'stemcell-name')
      stemcell = DeploymentPlan::Stemcell.new('stemcell-name-alias', 'stemcell-name', nil, model.version)
      stemcell.bind_model(deployment_model)
      stemcell
    end

    let(:different_stemcell) do
      model = Models::Stemcell.make(cid: 'different-stemcell-cid', name: 'different-stemcell-name')
      stemcell = DeploymentPlan::Stemcell.new('stemcell-name-diff-alias', 'different-stemcell-name', nil, model.version)
      stemcell.bind_model(deployment_model)
      stemcell
    end

    let(:vm_deleter) { VmDeleter.new(Config.logger, false, false) }
    let(:agent_broadcaster) { AgentBroadcaster.new }
    let(:dns_encoder) { LocalDnsEncoderManager.new_encoder_with_updated_index([]) }
    let(:vm_creator) { VmCreator.new(Config.logger, vm_deleter, disk_manager, template_blob_cache, dns_encoder, agent_broadcaster) }
    let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
    let(:disk_manager) { DiskManager.new(logger) }
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
    let(:deployment_model) { Models::Deployment.make(name: 'mycloud') }
    let(:deployment_plan) do
      instance_double(Bosh::Director::DeploymentPlan::Planner,
        compilation: compilation_config,
        model: deployment_model,
        name: 'mycloud',
        ip_provider: ip_provider,
        recreate: false,
        template_blob_cache: template_blob_cache,
      )
    end
    let(:subnet) {instance_double('Bosh::Director::DeploymentPlan::ManualNetworkSubnet', range: NetAddr::CIDR.create('192.168.0.0/24'))}
    let(:network) do
      instance_double('Bosh::Director::DeploymentPlan::ManualNetwork', name: 'a', subnets: [subnet])
    end
    let(:n_workers) { 3 }
    let(:cloud_properties) { { 'cloud' => 'properties'} }
    let(:expected_groups) {
      [
        'fake-director-name',
        'mycloud',
        'compilation-deadbeef',
        'fake-director-name-mycloud',
        'mycloud-compilation-deadbeef',
        'fake-director-name-mycloud-compilation-deadbeef'
      ]
    }
    let(:compilation_env) { { 'compilation' => 'environment', 'bosh' => { 'group' => 'fake-director-name-mycloud-compilation-deadbeef', 'groups' => expected_groups} } }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:another_agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:network_settings) { {'a' => {'property' => 'settings'}} }
    let(:trusted_certs) { "Trust me. I know what I'm doing." }
    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
      allow(thread_pool).to receive(:process).and_yield
      allow(thread_pool).to receive(:working?).and_return(false)
      thread_pool
    end
    let(:instance_deleter) { instance_double(Bosh::Director::InstanceDeleter) }
    let(:ip_provider) {instance_double(DeploymentPlan::IpProvider, reserve: nil, release: nil)}
    let(:max_instance_count) { 1 }
    let(:expected_network_settings) do
      {
        'a' => {
          'a' => {'property' => 'settings'},
        }
      }
    end
    let(:event_manager) {Api::EventManager.new(true)}
    let(:task_id) {42}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager)}
    before do
      allow(cloud).to receive(:create_vm)
      allow(network).to receive(:network_settings).with(instance_of(DesiredNetworkReservation), ['dns', 'gateway'], availability_zone).and_return(network_settings)
      allow(Config).to receive(:trusted_certs).and_return(trusted_certs)
      allow(Config).to receive(:name).and_return('fake-director-name')
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)
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
    end
    let(:availability_zone) { nil }

    let(:create_instance_error) { RuntimeError.new('failed to create instance') }

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
            compilation_env
          )
        action
      end

      it 'applies initial vm state' do
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1')
        expected_apply_spec = {
          'deployment' => 'mycloud',
          'job' => {
            'name' => 'compilation-deadbeef'
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

      it 'should record creation event' do
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1')
        expect {
          action
        }.to change {
          Bosh::Director::Models::Event.count }.from(0).to(4)

        event_1 = Bosh::Director::Models::Event.order(:id).first
        expect(event_1.user).to eq('user')
        expect(event_1.action).to eq('create')
        expect(event_1.object_type).to eq('instance')
        expect(event_1.object_name).to eq('compilation-deadbeef/instance-uuid-1')
        expect(event_1.task).to eq("#{task_id}")
        expect(event_1.deployment).to eq('mycloud')
        expect(event_1.instance).to eq('compilation-deadbeef/instance-uuid-1')

        event_2 = Bosh::Director::Models::Event.order(:id).last
        expect(event_2.parent_id).to eq(1)
        expect(event_2.user).to eq('user')
        expect(event_2.action).to eq('create')
        expect(event_2.object_type).to eq('instance')
        expect(event_2.object_name).to eq('compilation-deadbeef/instance-uuid-1')
        expect(event_2.task).to eq("#{task_id}")
        expect(event_2.deployment).to eq('mycloud')
        expect(event_2.instance).to eq('compilation-deadbeef/instance-uuid-1')
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
            expect {
              action_that_raises
            }.to raise_error (RuntimeError)
            event_2 = Bosh::Director::Models::Event.order(:id).last
            expect(event_2.error).to eq("failed to create instance")
          end
        end
      end
    end

    describe 'with_reused_vm' do
      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_reused_vm(stemcell) {} }
        let(:action_that_raises) do
          allow(vm_creator).to receive(:create_for_instance_plan).and_raise(create_instance_error)
          compilation_instance_pool.with_reused_vm(stemcell)
        end
      end

      context 'when the the pool is full' do
        context 'and there are no available instances for the given stemcell' do
          it 'destroys the idle instance made for a different stemcell' do
            compilation_instance_pool.with_reused_vm(stemcell) {|i| }
            expect(instance_deleter).to_not have_received(:delete_instance_plan)
            expect(instance_reuser.get_num_instances(stemcell)).to eq(1)

            compilation_instance_pool.with_reused_vm(different_stemcell) {|i| }

            expect(instance_reuser.get_num_instances(stemcell)).to eq(0)
            expect(instance_reuser.get_num_instances(different_stemcell)).to eq(1)
            expect(instance_deleter).to have_received(:delete_instance_plan)
          end
        end
      end

      context 'after a vm is created' do
        it 'is reused' do
          original = nil
          compilation_instance_pool.with_reused_vm(stemcell) do |instance|
            original = instance
          end
          reused = nil
          compilation_instance_pool.with_reused_vm(stemcell) do |instance|
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
          DeploymentPlan::CompilationConfig.new(compilation_spec, {'foo-az' => availability_zone }, [])
        end

        let(:max_instance_count) { 4 }

        let(:availability_zone) { DeploymentPlan::AvailabilityZone.new('foo-az', cloud_properties) }

        let(:deployment_model) { Models::Deployment.make(name: 'mycloud', cloud_config: cloud_config) }
        let(:cloud_config) { Models::CloudConfig.make(raw_manifest: Bosh::Spec::Deployments.simple_cloud_config.merge('azs' => [{'name' => 'foo-az'}])) }
        let(:dns_encoder) { LocalDnsEncoderManager.new_encoder_with_updated_index([availability_zone]) }
        let(:vm_creator) { instance_double('Bosh::Director::VmCreator') }

        before do
          allow(vm_creator).to receive(:create_for_instance_plan)
          allow(VmCreator).to receive(:new).with(logger, vm_deleter, disk_manager, template_blob_cache, agent_broadcaster).and_return(vm_creator)
        end

        it 'spins up vm in the az' do
          vm_instance = nil
          compilation_instance_pool.with_reused_vm(stemcell) do |instance|
            vm_instance = instance
          end
          expect(vm_instance.availability_zone_name).to eq('foo-az')
        end

        it 'saves az name in database' do
          allow(SecureRandom).to receive(:uuid).and_return('deadbeef', 'instance-uuid-1')
          compilation_instance_pool.with_reused_vm(stemcell) {}

          expect(Models::Instance.find(uuid: 'instance-uuid-1').availability_zone).to eq('foo-az')
        end
      end

      context 'when vm_type is specified' do
        let(:compilation_config) do
          compilation_spec = {
              'workers' => n_workers,
              'network' => 'a',
              'vm_type' => 'type-a'
          }
          vm_type_spec = {
            'name' => 'type-a',
            'cloud_properties' => {
              'instance_type' => 'big'
            }
          }
          DeploymentPlan::CompilationConfig.new(compilation_spec, {}, [DeploymentPlan::VmType.new(vm_type_spec)])
        end

        let(:max_instance_count) { 4 }

        it 'spins up vm with the correct VM type' do
          expect(cloud).to receive(:create_vm).with(
              anything,
              anything,
              {'instance_type' => 'big'},
              anything,
              anything,
              anything
            )

          compilation_instance_pool.with_reused_vm(stemcell) {}
        end
      end

      context 'when vm raises an Rpc timeout error' do
        it 'removes the vm from the reuser' do
          expect(instance_reuser).to receive(:remove_instance)
          expect {
            compilation_instance_pool.with_reused_vm(stemcell) { raise create_instance_error }
          }.to raise_error(create_instance_error)
        end

        context 'when keep_unreachable_vms is set' do
          before { Config.keep_unreachable_vms = true }

          it 'removes the vm from the reuser so that it is not cleaned up later when reuser deletes all instances' do
            expect(instance_reuser).to receive(:remove_instance)
            expect {
              compilation_instance_pool.with_reused_vm(stemcell) { raise create_instance_error }
            }.to raise_error(create_instance_error)
          end
        end
      end

      context 'when vm raises an Rpc timeout error' do
        it 'no longer offers that vm for reuse' do
          original = nil
          compilation_instance_pool.with_reused_vm(stemcell) do |instance|
            original = instance
          end

          expect {
            compilation_instance_pool.with_reused_vm(stemcell) { raise create_instance_error }
          }.to raise_error(create_instance_error)

          different = nil
          compilation_instance_pool.with_reused_vm(stemcell) do |instance|
            different = instance
          end
          expect(different).to_not eq(original)
        end
      end

      describe 'delete_instances' do
        let(:max_instance_count) { 2 }

        before do
          compilation_instance_pool.with_reused_vm(stemcell) {}
          compilation_instance_pool.with_reused_vm(another_stemcell) {}
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
    end

    describe 'with_single_use_vm' do
      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_single_use_vm(stemcell) {} }
        let(:action_that_raises) do
          allow(vm_creator).to receive(:create_for_instance_plan).and_raise(create_instance_error)
          compilation_instance_pool.with_single_use_vm(stemcell)
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
        allow(InstanceReuser).to receive(:new).and_return(instance_reuser)
        allow(DiskManager).to receive(:new).with(logger).and_return(disk_manager)
        allow(AgentBroadcaster).to receive(:new).and_return(agent_broadcaster)
        allow(PowerDnsManagerProvider).to receive(:create).and_return(powerdns_manager)
        allow(VmDeleter).to receive(:new).with(logger, false, false).and_return(vm_deleter)
        allow(VmCreator).to receive(:new).with(logger, vm_deleter, disk_manager, template_blob_cache, anything, agent_broadcaster).and_return(vm_creator)
        allow(InstanceDeleter).to receive(:new).with(ip_provider, powerdns_manager, disk_manager).and_return(instance_deleter)
        allow(DeploymentPlan::InstanceProvider).to receive(:new).with(deployment_plan, vm_creator, logger).and_return(instance_provider)
        allow(Config).to receive(:logger).and_return(logger)
        allow(Config).to receive(:enable_virtual_delete_vms).and_return(false)
        allow(deployment_plan).to receive(:availability_zones).and_return([])

        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
      end

      it 'creates the needed collaborators and news up a CompilationInstancePool' do
        expect(DeploymentPlan::CompilationInstancePool).to receive(:new).with(
          instance_reuser,
          instance_provider,
          logger,
          instance_deleter,
          n_workers,
        ).and_call_original

        DeploymentPlan::CompilationInstancePool.create(deployment_plan)
      end
    end
  end

  describe DeploymentPlan::CompilationJob do
    it "has no 'lifecycle'" do
      expect(DeploymentPlan::CompilationJob.new(nil, nil, nil, nil, nil, nil).lifecycle).to be_nil
    end
  end
end
