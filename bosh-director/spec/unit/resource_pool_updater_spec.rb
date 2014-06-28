# Copyright (c) 2009-2012 VMware, Inc.

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
        allow(resource_pool).to receive(:allocated_vms).and_return([])
        allow(resource_pool).to receive(:idle_vms).and_return([])

        resource_pool_updater.should_not_receive(:create_missing_vm)
        resource_pool_updater.create_missing_vms(thread_pool)
      end

      it 'should create missing VMs' do
        vm = instance_double('Bosh::Director::DeploymentPlan::Vm')
        allow(vm).to receive(:model).and_return(nil)

        allow(resource_pool).to receive(:allocated_vms).and_return([])
        allow(resource_pool).to receive(:idle_vms).and_return([vm])

        thread_pool.should_receive(:process).and_yield

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
