# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe ResourcePoolUpdater do
    subject(:resource_pool_updater) { ResourcePoolUpdater.new(resource_pool) }
    let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'large') }

    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:thread_pool) { instance_double('Bosh::ThreadPool') }

    before do
      Config.stub(:cloud).and_return(cloud)
      allow(thread_pool).to receive(:process).and_yield
    end

    describe :create_missing_vms do
      it 'should do nothing when everything is created' do
        resource_pool.stub(:allocated_vms).and_return([])
        resource_pool.stub(:idle_vms).and_return([])

        resource_pool_updater.should_not_receive(:create_missing_vm)
        resource_pool_updater.create_missing_vms(thread_pool)
      end

      it 'should create missing VMs' do
        vm = instance_double('Bosh::Director::DeploymentPlan::Vm')
        vm.stub(:model).and_return(nil)

        resource_pool.stub(:allocated_vms).and_return([])
        resource_pool.stub(:idle_vms).and_return([vm])

        thread_pool.should_receive(:process).and_yield

        resource_pool_updater.should_receive(:create_missing_vm).with(vm)
        resource_pool_updater.create_missing_vms(thread_pool)
      end
    end

    describe :create_bound_missing_vms do
      it 'should call create_missing_vms with the right filter' do
        bound_vm = double(:Vm)
        bound_vm.stub(:bound_instance).and_return(double(DeploymentPlan::Instance))
        unbound_vm = double(:Vm)
        unbound_vm.stub(:bound_instance).and_return(nil)

        called = false
        resource_pool_updater.should_receive(:create_missing_vms) do |&block|
          called = true
          block.call(bound_vm).should == true
          block.call(unbound_vm).should == false
        end
        resource_pool_updater.create_bound_missing_vms(thread_pool)
        called.should == true
      end
    end

    describe :create_missing_vm do
      before do
        @vm = instance_double('Bosh::Director::DeploymentPlan::Vm')
        @network_settings = {'network' => 'settings'}
        @vm.stub(:network_settings).and_return(@network_settings)
        @deployment = Models::Deployment.make
        @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
        @deployment_plan.stub(:model).and_return(@deployment)
        @stemcell = Models::Stemcell.make
        @stemcell_spec = instance_double('Bosh::Director::DeploymentPlan::Stemcell')
        @stemcell_spec.stub(:model).and_return(@stemcell)
        resource_pool.stub(:deployment_plan).and_return(@deployment_plan)
        resource_pool.stub(:stemcell).and_return(@stemcell_spec)
        @cloud_properties = {'size' => 'medium'}
        resource_pool.stub(:cloud_properties).and_return(@cloud_properties)
        @environment = {'password' => 'foo'}
        resource_pool.stub(:env).and_return(@environment)
        @vm_model = Models::Vm.make(agent_id:  'agent-1', cid:  'vm-1')
        @vm_creator = instance_double('Bosh::Director::VmCreator')
        @vm_creator.stub(:create).
            with(@deployment, @stemcell, @cloud_properties, @network_settings,
                 nil, @environment).
            and_return(@vm_model)
        VmCreator.stub(:new).and_return(@vm_creator)
      end

      it 'should create a VM' do
        agent = double(:AgentClient)
        agent.should_receive(:wait_until_ready)
        agent.should_receive(:get_state).and_return({'state' => 'foo'})
        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        resource_pool_updater.should_receive(:update_state).with(agent, @vm_model, @vm)
        @vm.should_receive(:model=).with(@vm_model)
        @vm.should_receive(:current_state=).with({'state' => 'foo'})

        resource_pool_updater.create_missing_vm(@vm)
      end

      it 'should clean up the partially created VM' do
        agent = double(:AgentClient)
        agent.should_receive(:wait_until_ready).and_raise('timeout')
        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        cloud.should_receive(:delete_vm).with('vm-1')

        lambda {
          resource_pool_updater.create_missing_vm(@vm)
        }.should raise_error('timeout')

        Models::Vm.count.should == 0
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
        resource_pool.stub(deployment_plan: deployment_plan)
        resource_pool.stub(spec: resource_pool_spec)
        vm_model.stub(:update)
        agent.stub(:apply)
      end

      it 'sends the agent an updated state' do
        agent.should_receive(:apply).with(apply_spec)
        resource_pool_updater.update_state(agent, vm_model, vm)
      end

      it 'updates the vm model with the updated state' do
        vm_model.should_receive(:update).with(apply_spec: apply_spec)
        resource_pool_updater.update_state(agent, vm_model, vm)
      end
    end

    describe :delete_extra_vms do
      let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-cid') }
      let(:vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: true, model: vm_model) }
      let(:unchanged_vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: false, model: vm_model) }

      before do
        allow(resource_pool).to receive(:active_vm_count).and_return(1)
        allow(resource_pool).to receive(:idle_vms).and_return([vm])
        allow(resource_pool).to receive(:allocated_vms).and_return([unchanged_vm])
      end

      context 'when the resource pool has a fixed size' do
        before do
          allow(resource_pool).to receive(:dynamically_sized?).and_return(false)
          allow(resource_pool).to receive(:size).and_return(2)
        end

        it 'deletes idle VMs until the pool is the expected size' do
          expect(cloud).to receive(:delete_vm).with('fake-cid')
          expect(vm_model).to receive(:destroy).with(no_args)

          resource_pool_updater.delete_extra_vms(thread_pool)
        end
      end

      context 'when the resource pool is dynamically sized' do
        before do
          allow(resource_pool).to receive(:dynamically_sized?).and_return(true)
        end

        it 'does not delete any VMs' do
          expect(cloud).to_not receive(:delete_vm)
          expect(vm_model).to_not receive(:destroy)

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
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::DynamicNetwork') }
      before { allow(resource_pool).to receive(:network).and_return(network) }

      let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-allocated-vm') }
      let(:allocated_vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: true, model: vm_model, network_reservation: nil) }

      let(:vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-idle-vm') }
      let(:vm) { instance_double('Bosh::Director::DeploymentPlan::Vm', changed?: true, model: vm_model, network_reservation: nil) }

      before do
        allow(resource_pool).to receive(:allocated_vms).and_return([allocated_vm])
        allow(resource_pool).to receive(:idle_vms).and_return([vm])
      end

      let(:network_reservation) { instance_double('Bosh::Director::NetworkReservation', reserved?: true) }

      it 'finds first unreserved network to reserve' do
        expect(NetworkReservation).to receive(:new).with(type: NetworkReservation::DYNAMIC).and_return(network_reservation).twice
        expect(network).to receive(:reserve).with(network_reservation).twice

        expect(vm).to receive(:network_reservation=).with(network_reservation)
        expect(allocated_vm).to receive(:network_reservation=).with(network_reservation)

        resource_pool_updater.reserve_networks
      end

      context 'when network was already reserved' do
        let(:network_reservation) do
          instance_double(
            'Bosh::Director::NetworkReservation',
            reserved?: false,
            error: 'fake-default-error'
          )
        end

        it 'raises an error' do
          expect(NetworkReservation).to receive(:new).with(type: NetworkReservation::DYNAMIC).and_return(network_reservation)
          expect(network).to receive(:reserve).with(network_reservation)
          expect {
            resource_pool_updater.reserve_networks
          }.to raise_error(NetworkReservationError,
            %r{'large/0' failed to reserve dynamic IP: fake-default-error}
          )
        end
      end

      context 'when network reservation fails with not enough capacity' do
        let(:network_reservation) do
          instance_double(
            'Bosh::Director::NetworkReservation',
            reserved?: false,
            error: NetworkReservation::CAPACITY
          )
        end

        it 'raises an error' do
          expect(NetworkReservation).to receive(:new).with(type: NetworkReservation::DYNAMIC).and_return(network_reservation)
          expect(network).to receive(:reserve).with(network_reservation)
          expect {
            resource_pool_updater.reserve_networks
          }.to raise_error(
            NetworkReservationNotEnoughCapacity,
            %r{'large/0' asked for a dynamic IP but there were no more available}
          )
        end
      end
    end
  end
end
