require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe DeploymentPlan::CompilationInstancePool do
    let(:instance_reuser) { InstanceReuser.new }
    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:stemcell) { instance_double(DeploymentPlan::Stemcell, model: Models::Stemcell.make) }
    let(:another_stemcell) { instance_double(DeploymentPlan::Stemcell, model: Models::Stemcell.make) }
    let(:vm_deleter) { VmDeleter.new(cloud, Config.logger) }
    let(:vm_creator) { VmCreator.new(cloud, Config.logger, vm_deleter) }
    let(:compilation_config) { instance_double('Bosh::Director::DeploymentPlan::CompilationConfig') }
    let(:deployment_model) { Models::Deployment.make(name: 'mycloud') }
    let(:deployment_plan) {instance_double('Bosh::Director::DeploymentPlan::Planner', compilation: compilation_config, model: deployment_model, name: 'mycloud')}
    let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'network name') }
    let(:n_workers) { 3 }
    let(:vm_model) { Models::Vm.make }
    let(:another_vm_model) { Models::Vm.make }
    let(:cloud_properties) { {cloud: 'properties'} }
    let(:compilation_env) { {compilation: 'environment'} }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:another_agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:reservation) { NetworkReservation.new({}) }
    let(:network_settings) { {'network name' => 'network settings'} }
    let(:trusted_certs) { "Trust me. I know what I'm doing." }
    let(:thread_pool) do
      thread_pool = instance_double('Bosh::Director::ThreadPool')
      allow(thread_pool).to receive(:wrap).and_yield(thread_pool)
      allow(thread_pool).to receive(:process).and_yield
      allow(thread_pool).to receive(:working?).and_return(false)
      thread_pool
    end

    let(:compilation_instance_pool) { DeploymentPlan::CompilationInstancePool.new(instance_reuser, vm_creator, vm_deleter, deployment_plan, logger) }

    before do
      allow(compilation_config).to receive_messages(
          network_name: 'network name',
          env: compilation_env,
          cloud_properties: cloud_properties,
          workers: n_workers,
          reuse_compilation_vms: false)
      allow(network).to receive(:reserve!) { |reservation, name| reservation.reserved = true }
      allow(NetworkReservation).to receive(:new_dynamic).and_return(reservation)
      allow(reservation).to receive(:reserved?).and_return(true)
      allow(network).to receive(:network_settings).with(reservation, ['dns', 'gateway']).and_return('network settings')
      allow(vm_creator).to receive(:create).and_return(vm_model, another_vm_model)
      allow(Config).to receive(:trusted_certs).and_return(trusted_certs)
      allow(AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client)
      allow(AgentClient).to receive(:with_vm).with(another_vm_model).and_return(another_agent_client)
      allow(agent_client).to receive(:wait_until_ready)
      allow(agent_client).to receive(:update_settings)
      allow(agent_client).to receive(:get_state)
      allow(agent_client).to receive(:apply)
      allow(another_agent_client).to receive(:wait_until_ready)
      allow(another_agent_client).to receive(:update_settings)
      allow(another_agent_client).to receive(:get_state)
      allow(another_agent_client).to receive(:apply)
      allow(network).to receive(:release)
      allow(ThreadPool).to receive_messages(new: thread_pool)
      allow(deployment_plan).to receive(:network).with('network name').and_return(network)
    end

    let(:create_instance_error) { RuntimeError.new('failed to create instance') }

    shared_examples_for 'a compilation vm pool' do
      context 'when network is not reserved' do
        before { allow(reservation).to receive(:reserved?).and_return(false) }

        it 'reserves a network for a new vm' do
          expect(network).to receive(:reserve!).with(reservation, /compilation-/)
          action
        end
      end

      it 'defers to the vm creator to create a vm' do
        expect(vm_creator).to receive(:create).with(
          deployment_model,
          stemcell,
          cloud_properties,
          network_settings,
          [],
          compilation_env
        ).and_return(vm_model)
        action
      end

      it 'applies vm state' do
        expected_apply_spec = {
          'deployment' => 'mycloud',
          'job' =>{},
          'index' => 0,
          'networks' => {
            'network name' => 'network settings'
          },
          'resource_pool' => {},
          'packages' => {},
          'configuration_hash' => nil,
          'properties' => {},
          'dns_domain_name' => nil,
          'links' => {},
          'persistent_disk' => 0
        }
        expect(agent_client).to receive(:apply).with(expected_apply_spec)

        action
        expect(vm_model.apply_spec).to eq(expected_apply_spec)
        expect(vm_model.trusted_certs_sha1).to eq(Digest::SHA1.hexdigest(trusted_certs))
      end

      context 'when instance creation fails' do
        before do
          allow(cloud).to receive(:delete_vm).with(vm_model.cid)
        end

        it 'deletes the vm from the cloud' do
          expect(cloud).to receive(:delete_vm).with(vm_model.cid)
          expect { action_that_raises }.to raise_error(create_instance_error)
        end

        it 'deletes the vm model from the db' do
          vm_model_id = vm_model.id
          expect { action_that_raises }.to raise_error(create_instance_error)
          expect(Models::Vm[vm_model_id]).to be_nil
        end

        it 'releases the network reservation' do
          expect(network).to receive(:release).with(reservation)
          expect { action_that_raises }.to raise_error(create_instance_error)
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

      context 'when vm raises an Rpc timeout error' do
        it 'removes the vm from the reuser' do
          expect(instance_reuser).to receive(:remove_instance)
          expect(cloud).to receive(:delete_vm)
          expect {
            compilation_instance_pool.with_reused_vm(stemcell) { raise create_instance_error }
          }.to raise_error(create_instance_error)
        end
      end

      context 'when vm raises an Rpc timeout error' do
        it 'no longer offers that vm for reuse' do
          expect(cloud).to receive(:delete_vm)
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

      describe 'tear_down_vms' do
        let(:number_of_workers) { 1 }
        before do
          allow(cloud).to receive(:delete_vm)
          compilation_instance_pool.with_reused_vm(stemcell) {}
          compilation_instance_pool.with_reused_vm(another_stemcell) {}
        end

        it 'removes the vm from the reuser' do
          expect(instance_reuser.get_num_instances(stemcell)).to eq(1)
          compilation_instance_pool.tear_down_vms(number_of_workers)
          expect(instance_reuser.get_num_instances(stemcell)).to eq(0)
        end

        it 'tears down each idle vm in vm pool' do
          expect(cloud).to receive(:delete_vm).with(vm_model.cid)
          expect(cloud).to receive(:delete_vm).with(another_vm_model.cid)

          compilation_instance_pool.tear_down_vms(number_of_workers)
        end
      end
    end

    describe 'with_single_use_vm' do
      before do
        allow(cloud).to receive(:delete_vm)
      end

      it_behaves_like 'a compilation vm pool' do
        let(:action) { compilation_instance_pool.with_single_use_vm(stemcell) {} }
        let(:action_that_raises) { compilation_instance_pool.with_single_use_vm(stemcell) { raise create_instance_error } }
      end
    end
  end
end

