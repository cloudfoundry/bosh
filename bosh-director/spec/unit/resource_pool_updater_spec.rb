require 'spec_helper'

module Bosh::Director
  describe ResourcePoolUpdater do
    subject(:resource_pool_updater) { ResourcePoolUpdater.new(resource_pool) }
    let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'large') }

    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:thread_pool) { instance_double('Bosh::ThreadPool') }

    before do
      allow(Config).to receive(:cloud).and_return(cloud)
      allow(thread_pool).to receive(:process).and_yield
    end

    describe :create_missing_vms do
      it 'should do nothing when everything is created' do
        allow(resource_pool).to receive(:vms).and_return([])

        expect(resource_pool_updater).not_to receive(:create_missing_vm)
        resource_pool_updater.create_missing_vms(thread_pool)
      end

      it 'should create missing VMs' do
        vm = instance_double('Bosh::Director::DeploymentPlan::Vm')
        allow(vm).to receive(:model).and_return(nil)

        allow(resource_pool).to receive(:vms).and_return([vm])

        expect(thread_pool).to receive(:process).and_yield

        expect(resource_pool_updater).to receive(:create_missing_vm).with(vm)
        resource_pool_updater.create_missing_vms(thread_pool)
      end
    end

    describe :create_bound_missing_vms do
      it 'should call create_missing_vms with the right filter' do
        bound_vm = double(:Vm)
        allow(bound_vm).to receive(:bound_instance).and_return(double(DeploymentPlan::Instance))
        unbound_vm = double(:Vm)
        allow(unbound_vm).to receive(:bound_instance).and_return(nil)

        called = false
        expect(resource_pool_updater).to receive(:create_missing_vms) do |&block|
          called = true
          expect(block.call(bound_vm)).to eq(true)
          expect(block.call(unbound_vm)).to eq(false)
        end
        resource_pool_updater.create_bound_missing_vms(thread_pool)
        expect(called).to eq(true)
      end
    end

    describe :create_missing_vm do
      before do
        @vm = instance_double('Bosh::Director::DeploymentPlan::Vm')
        @network_settings = {'network' => 'settings'}
        allow(@vm).to receive(:network_settings).and_return(@network_settings)
        @deployment = Models::Deployment.make
        @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
        allow(@deployment_plan).to receive(:model).and_return(@deployment)
        @stemcell = Models::Stemcell.make
        @stemcell_spec = instance_double('Bosh::Director::DeploymentPlan::Stemcell')
        allow(@stemcell_spec).to receive(:model).and_return(@stemcell)
        allow(resource_pool).to receive(:deployment_plan).and_return(@deployment_plan)
        allow(resource_pool).to receive(:stemcell).and_return(@stemcell_spec)
        @cloud_properties = {'size' => 'medium'}
        allow(resource_pool).to receive(:cloud_properties).and_return(@cloud_properties)
        @environment = {'password' => 'foo'}
        allow(resource_pool).to receive(:env).and_return(@environment)
        @vm_model = Models::Vm.make(agent_id:  'agent-1', cid:  'vm-1')
        @vm_creator = instance_double('Bosh::Director::VmCreator')
        allow(@vm_creator).to receive(:create).
            with(@deployment, @stemcell, @cloud_properties, @network_settings,
                 nil, @environment).
            and_return(@vm_model)
        allow(VmCreator).to receive(:new).and_return(@vm_creator)
      end

      it 'should create a VM' do
        agent = double(:AgentClient)
        expect(agent).to receive(:wait_until_ready)
        expect(agent).to receive(:update_settings)
        expect(agent).to receive(:get_state).and_return({'state' => 'foo'})
        allow(AgentClient).to receive(:with_defaults).with('agent-1').and_return(agent)

        expect(resource_pool_updater).to receive(:update_state).with(agent, @vm_model, @vm)
        expect(@vm).to receive(:model=).with(@vm_model)
        expect(@vm).to receive(:current_state=).with({'state' => 'foo'})

        resource_pool_updater.create_missing_vm(@vm)
      end

      context 'trusted certificate handling' do
        let(:agent) { double(:AgentClient) }
        before do
          Bosh::Director::Config.trusted_certs=DIRECTOR_TEST_CERTS
          allow(agent).to receive(:wait_until_ready)
          allow(agent).to receive(:update_settings)
          allow(agent).to receive(:get_state).and_return({'state' => 'foo'})
          allow(AgentClient).to receive(:with_defaults).and_return(agent)

          allow(resource_pool_updater).to receive(:update_state).with(agent, @vm_model, @vm)
          allow(@vm).to receive(:model=).with(@vm_model)
          allow(@vm).to receive(:current_state=).with({'state' => 'foo'})
        end

        it 'should update the database with the new VM''s trusted certs' do
          resource_pool_updater.create_missing_vm(@vm)
          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1, agent_id: @vm_model.agent_id).count).to eq(1)
        end

        it 'should not update the DB with the new certificates when the new vm fails to start' do
          expect(agent).to receive(:wait_until_ready).and_raise(RpcTimeout)

          begin
            resource_pool_updater.create_missing_vm(@vm)
          rescue RpcTimeout
            # expected
          end

          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
        end

        it 'should not update the DB with the new certificates when the update_settings method fails' do
          expect(agent).to receive(:update_settings).and_raise(RpcTimeout)

          begin
            resource_pool_updater.create_missing_vm(@vm)
          rescue RpcTimeout
            # expected
          end

          expect(Models::Vm.where(trusted_certs_sha1: DIRECTOR_TEST_CERTS_SHA1).count).to eq(0)
        end
      end

      it 'should create a VM' do
        agent = double(:AgentClient)
        expect(agent).to receive(:wait_until_ready)
        expect(agent).to receive(:update_settings)
        expect(agent).to receive(:get_state).and_return({'state' => 'foo'})
        allow(AgentClient).to receive(:with_defaults).with('agent-1').and_return(agent)

        expect(resource_pool_updater).to receive(:update_state).with(agent, @vm_model, @vm)
        expect(@vm).to receive(:model=).with(@vm_model)
        expect(@vm).to receive(:current_state=).with({'state' => 'foo'})

        resource_pool_updater.create_missing_vm(@vm)
      end

      it 'should clean up the partially created VM' do
        agent = double(:AgentClient)
        expect(agent).to receive(:wait_until_ready).and_raise('timeout')
        allow(AgentClient).to receive(:with_defaults).with('agent-1').and_return(agent)

        expect(cloud).to receive(:delete_vm).with('vm-1')

        expect {
          resource_pool_updater.create_missing_vm(@vm)
        }.to raise_error('timeout')

        expect(Models::Vm.count).to eq(0)
      end
    end

    describe '#update_state' do
      let(:vm_model) { instance_double('Bosh::Director::Models::Vm') }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }
      let(:network_settings) { {'network1' => {}} }
      let(:vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', network_settings: network_settings, bound_instance: instance) }
      let(:resource_pool_spec) { {} }
      let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', spec: {}) }
      let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'foo') }
      let(:apply_spec) do
        {
            'deployment' => deployment_plan.name,
            'resource_pool' => resource_pool_spec,
            'networks' => network_settings,
        }
      end

      before do
        allow(resource_pool).to receive(:deployment_plan).and_return(deployment_plan)
        allow(resource_pool).to receive(:spec).and_return(resource_pool_spec)
        allow(vm_model).to receive(:update)
        allow(agent).to receive(:apply)
      end

      it 'sends the agent an updated state' do
        expect(agent).to receive(:apply).with(apply_spec)
        resource_pool_updater.update_state(agent, vm_model, vm)
      end

      it 'updates the vm model with the updated state' do
        expect(vm_model).to receive(:update).with(apply_spec: apply_spec)
        resource_pool_updater.update_state(agent, vm_model, vm)
      end
    end

    describe :delete_extra_vms do
      let(:vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: true, model: vm_model1) }
      let(:extra_vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: false, model: vm_model2) }
      let(:vm_model1) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-cid1') }
      let(:vm_model2) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-cid2') }

      before do
        allow(resource_pool).to receive(:idle_vms).and_return([extra_vm, vm]) #deleted from the front
      end

      context 'when the resource pool has extra VMs' do
        before do
          allow(resource_pool).to receive(:extra_vm_count).and_return(1)
        end

        it 'deletes the extra VMs' do
          expect(cloud).to receive(:delete_vm).with(extra_vm.model.cid)
          expect(extra_vm.model).to receive(:destroy).with(no_args)

          resource_pool_updater.delete_extra_vms(thread_pool)
        end
      end

      context 'when the resource pool does not have extra VMs' do
        before do
          allow(resource_pool).to receive(:extra_vm_count).and_return(0)
        end

        it 'does not delete any VMs' do
          expect(cloud).to_not receive(:delete_vm)
          expect(vm.model).to_not receive(:destroy)
          expect(extra_vm.model).to_not receive(:destroy)

          resource_pool_updater.delete_extra_vms(thread_pool)
        end
      end
    end

    describe '#delete_outdated_vms' do
      let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-cid') }
      let(:vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: true, model: vm_model) }
      let(:unchanged_vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: false, model: vm_model) }
      let(:vm_without_vm_model) { instance_double('Bosh::Director::DeploymentPlan::Vm', model: nil, changed?: true) }

      before do
        allow(resource_pool).to receive(:idle_vms).and_return([vm, unchanged_vm, vm_without_vm_model])
      end

      it 'deletes each idle vm in resource pool' do
        expect(cloud).to receive(:delete_vm).with('fake-cid')

        expect(vm).to receive(:clean_vm).with(no_args)
        expect(unchanged_vm).to_not receive(:clean_vm).with(no_args)
        expect(vm_without_vm_model).to_not receive(:clean_vm).with(no_args)

        expect(vm_model).to receive(:destroy).with(no_args)

        resource_pool_updater.delete_outdated_idle_vms(thread_pool)
      end
    end

    describe '#reserve_networks' do
      it 'delegates to ResourcePool#reserve_dynamic_networks' do
        expect(resource_pool).to receive(:reserve_dynamic_networks).with(no_args)
        resource_pool_updater.reserve_networks
      end
    end
  end
end
