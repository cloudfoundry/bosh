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
        idle_vm = double(:IdleVm)
        idle_vm.stub(:vm).and_return(nil)

        resource_pool.stub(:allocated_vms).and_return([])
        resource_pool.stub(:idle_vms).and_return([idle_vm])

        thread_pool.should_receive(:process).and_yield

        resource_pool_updater.should_receive(:create_missing_vm).with(idle_vm)
        resource_pool_updater.create_missing_vms(thread_pool)
      end
    end

    describe :create_bound_missing_vms do
      it 'should call create_missing_vms with the right filter' do
        bound_vm = double(:IdleVm)
        bound_vm.stub(:bound_instance).
            and_return(double(DeploymentPlan::Instance))
        unbound_vm = double(:IdleVm)
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
        @idle_vm = double(:IdleVm)
        @network_settings = {'network' => 'settings'}
        @idle_vm.stub(:network_settings).and_return(@network_settings)
        @deployment = Models::Deployment.make
        @deployment_plan = double(:DeploymentPlan)
        @deployment_plan.stub(:model).and_return(@deployment)
        @stemcell = Models::Stemcell.make
        @stemcell_spec = double(:Stemcell)
        @stemcell_spec.stub(:model).and_return(@stemcell)
        resource_pool.stub(:deployment_plan).and_return(@deployment_plan)
        resource_pool.stub(:stemcell).and_return(@stemcell_spec)
        @cloud_properties = {'size' => 'medium'}
        resource_pool.stub(:cloud_properties).and_return(@cloud_properties)
        @environment = {'password' => 'foo'}
        resource_pool.stub(:env).and_return(@environment)
        @vm = Models::Vm.make(agent_id:  'agent-1', cid:  'vm-1')
        @vm_creator = double(:VmCreator)
        @vm_creator.stub(:create).
            with(@deployment, @stemcell, @cloud_properties, @network_settings,
                 nil, @environment).
            and_return(@vm)
        VmCreator.stub(:new).and_return(@vm_creator)
      end

      it 'should create a VM' do
        agent = double(:AgentClient)
        agent.should_receive(:wait_until_ready)
        agent.should_receive(:get_state).and_return({'state' => 'foo'})
        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        resource_pool_updater.should_receive(:update_state).with(agent, @vm, @idle_vm)
        @idle_vm.should_receive(:vm=).with(@vm)
        @idle_vm.should_receive(:current_state=).with({'state' => 'foo'})

        resource_pool_updater.create_missing_vm(@idle_vm)
      end

      it 'should clean up the partially created VM' do
        agent = double(:AgentClient)
        agent.should_receive(:wait_until_ready).and_raise('timeout')
        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        cloud.should_receive(:delete_vm).with('vm-1')

        lambda {
          resource_pool_updater.create_missing_vm(@idle_vm)
        }.should raise_error('timeout')

        Models::Vm.count.should == 0
      end
    end

    describe '#update_state' do
      let(:vm) { double('VM') }
      let(:agent) { double('Agent') }
      let(:network_settings) { {'network1' => {}} }
      let(:idle_vm) { double('Idle VM', network_settings: network_settings, bound_instance: instance) }
      let(:resource_pool_spec) { {} }
      let(:instance) { double('Instance', spec: {}) }
      let(:deployment_plan) { double('DeploymentPlan', name: 'foo') }
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
        vm.stub(:update)
        agent.stub(:apply)
      end

      it 'sends the agent an updated state' do
        agent.should_receive(:apply).with(apply_spec)
        resource_pool_updater.update_state(agent, vm, idle_vm)
      end

      it 'updates the vm model with the updated state' do
        vm.should_receive(:update).with(apply_spec: apply_spec)
        resource_pool_updater.update_state(agent, vm, idle_vm)
      end
    end

    describe :delete_extra_vms

    describe '#delete_outdated_idle_vms' do
      let(:vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-cid') }
      let(:idle_vm) { instance_double('Bosh::Director::DeploymentPlan::IdleVm', changed?: true, vm: vm) }
      let(:unchanged_idle_vm) { instance_double('Bosh::Director::DeploymentPlan::IdleVm', changed?: false, vm: vm) }
      let(:idle_vm_without_vm) { instance_double('Bosh::Director::DeploymentPlan::IdleVm', vm: nil, changed?: true) }

      before do
        allow(resource_pool).to receive(:idle_vms).and_return([idle_vm, unchanged_idle_vm, idle_vm_without_vm])
      end

      it 'deletes each idle vm in resource pool' do
        expect(cloud).to receive(:delete_vm).with('fake-cid')

        expect(idle_vm).to receive(:clean_vm).with(no_args)
        expect(unchanged_idle_vm).to_not receive(:clean_vm).with(no_args)
        expect(idle_vm_without_vm).to_not receive(:clean_vm).with(no_args)

        expect(vm).to receive(:destroy).with(no_args)

        resource_pool_updater.delete_outdated_idle_vms(thread_pool)
      end
    end

    describe '#reserve_networks' do
      let(:network) { instance_double('Bosh::Director::DeploymentPlan::DynamicNetwork') }
      before { allow(resource_pool).to receive(:network).and_return(network) }

      let(:vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-allocated-vm') }
      let(:allocated_vm) { instance_double('Bosh::Director::DeploymentPlan::IdleVm', changed?: true, vm: vm, network_reservation: nil) }

      let(:vm) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-idle-vm') }
      let(:idle_vm) { instance_double('Bosh::Director::DeploymentPlan::IdleVm', changed?: true, vm: vm, network_reservation: nil) }

      before do
        allow(resource_pool).to receive(:allocated_vms).and_return([allocated_vm])
        allow(resource_pool).to receive(:idle_vms).and_return([idle_vm])
      end

      let(:network_reservation) { instance_double('Bosh::Director::NetworkReservation', reserved?: true) }

      it 'finds first unreserved network to reserve' do
        expect(NetworkReservation).to receive(:new).with(type: NetworkReservation::DYNAMIC).and_return(network_reservation).twice
        expect(network).to receive(:reserve).with(network_reservation).twice

        expect(idle_vm).to receive(:network_reservation=).with(network_reservation)
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
