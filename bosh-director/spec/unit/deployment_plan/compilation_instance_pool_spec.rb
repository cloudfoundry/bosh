require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe DeploymentPlan::CompilationInstancePool do
    let(:instance_reuser) { InstanceReuser.new }
    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:stemcell) { instance_double(DeploymentPlan::Stemcell, model: Models::Stemcell.make, spec: {'name' => 'stemcell-name'}, cid: 'stemcell-cid') }
    let(:another_stemcell) { instance_double(DeploymentPlan::Stemcell, model: Models::Stemcell.make, spec: {'name' => 'stemcell-name'}, cid: 'another-stemcell-cid') }
    let(:vm_deleter) { VmDeleter.new(cloud, Config.logger) }
    let(:vm_creator) { VmCreator.new(cloud, Config.logger, vm_deleter, disk_manager, job_renderer) }
    let(:job_renderer) { instance_double(JobRenderer, render_job_instance: nil) }
    let(:disk_manager) {DiskManager.new(cloud, logger)}
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
        recreate: false
      )
    end
    let(:subnet) {instance_double('Bosh::Director::DeploymentPlan::ManualNetworkSubnet', range: NetAddr::CIDR.create('192.168.0.0/24'))}
    let(:network) do
      instance_double('Bosh::Director::DeploymentPlan::ManualNetwork', name: 'a', subnets: [subnet])
    end
    let(:n_workers) { 3 }
    let(:cloud_properties) { { 'cloud' => 'properties'} }
    let(:compilation_env) { { 'compilation' => 'environment'} }
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

    let(:compilation_instance_pool) { DeploymentPlan::CompilationInstancePool.new(instance_reuser, vm_creator, deployment_plan, logger, instance_deleter) }
    let(:expected_network_settings) do
      {
        'a' => {
          'a' => {'property' => 'settings'},
        }
      }
    end

    before do
      allow(cloud).to receive(:create_vm)
      allow(network).to receive(:network_settings).with(instance_of(DesiredNetworkReservation), ['dns', 'gateway'], availability_zone).and_return(network_settings)
      allow(Config).to receive(:trusted_certs).and_return(trusted_certs)
      allow(Config).to receive(:cloud).and_return(instance_double('Bosh::Cloud'))
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
            stemcell.cid,
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
        expect(compilation_instance.trusted_certs_sha1).to eq(Digest::SHA1.hexdigest(trusted_certs))
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
        end
      end
    end

    describe 'with_reused_vm' do
      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_reused_vm(stemcell) {} }
        let(:action_that_raises) { compilation_instance_pool.with_reused_vm(stemcell) { raise(create_instance_error) } }
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

        let(:compilation_instance_pool) do
          DeploymentPlan::CompilationInstancePool.new(instance_reuser, vm_creator, deployment_plan, logger, instance_deleter)
        end

        let(:availability_zone) { DeploymentPlan::AvailabilityZone.new('foo-az', cloud_properties) }

        it 'spins up vm in the az' do
          vm_instance = nil
          compilation_instance_pool.with_reused_vm(stemcell) do |instance|
            vm_instance = instance
          end
          expect(vm_instance.availability_zone_name).to eq('foo-az')
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

        let(:compilation_instance_pool) do
          DeploymentPlan::CompilationInstancePool.new(instance_reuser, vm_creator, deployment_plan, logger, instance_deleter)
        end

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
        let(:number_of_workers) { 1 }
        before do
          compilation_instance_pool.with_reused_vm(stemcell) {}
          compilation_instance_pool.with_reused_vm(another_stemcell) {}
        end

        it 'removes the vm from the reuser' do
          expect(instance_reuser.get_num_instances(stemcell)).to eq(1)
          compilation_instance_pool.delete_instances(number_of_workers)
          expect(instance_reuser.get_num_instances(stemcell)).to eq(0)
        end

        it 'deletes the instance' do
          compilation_instance_pool.delete_instances(number_of_workers)
          expect(instance_deleter).to have_received(:delete_instance_plan).exactly(2).times
        end
      end
    end

    describe 'with_single_use_vm' do
      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_single_use_vm(stemcell) {} }
        let(:action_that_raises) { compilation_instance_pool.with_single_use_vm(stemcell) { raise create_instance_error } }
      end
    end
  end
end

