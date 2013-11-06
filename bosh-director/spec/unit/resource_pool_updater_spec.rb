# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe ResourcePoolUpdater do
    before do
      @cloud = double(:Cloud)
      Config.stub(:cloud).and_return(@cloud)

      @resource_pool = double(:ResourcePool)
      @resource_pool.stub(:name).and_return('large')
      @resource_pool_updater = ResourcePoolUpdater.new(@resource_pool)
    end

    describe :create_missing_vms do
      it 'should do nothing when everything is created' do
        pool = double(:ThreadPool)

        @resource_pool.stub(:allocated_vms).and_return([])
        @resource_pool.stub(:idle_vms).and_return([])

        @resource_pool_updater.should_not_receive(:create_missing_vm)
        @resource_pool_updater.create_missing_vms(pool)
      end

      it 'should create missing VMs' do
        pool = double(:ThreadPool)

        idle_vm = double(:IdleVm)
        idle_vm.stub(:vm).and_return(nil)

        @resource_pool.stub(:allocated_vms).and_return([])
        @resource_pool.stub(:idle_vms).and_return([idle_vm])

        pool.should_receive(:process).and_yield

        @resource_pool_updater.should_receive(:create_missing_vm).with(idle_vm)
        @resource_pool_updater.create_missing_vms(pool)
      end
    end

    describe :create_bound_missing_vms do
      it 'should call create_missing_vms with the right filter' do
        pool = double(:ThreadPool)

        bound_vm = double(:IdleVm)
        bound_vm.stub(:bound_instance).
            and_return(double(DeploymentPlan::Instance))
        unbound_vm = double(:IdleVm)
        unbound_vm.stub(:bound_instance).and_return(nil)

        called = false
        @resource_pool_updater.should_receive(:create_missing_vms).and_return do |&block|
          called = true
          block.call(bound_vm).should == true
          block.call(unbound_vm).should == false
        end
        @resource_pool_updater.create_bound_missing_vms(pool)
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
        @resource_pool.stub(:deployment_plan).and_return(@deployment_plan)
        @resource_pool.stub(:stemcell).and_return(@stemcell_spec)
        @cloud_properties = {'size' => 'medium'}
        @resource_pool.stub(:cloud_properties).and_return(@cloud_properties)
        @environment = {'password' => 'foo'}
        @resource_pool.stub(:env).and_return(@environment)
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

        @resource_pool_updater.should_receive(:update_state).with(agent, @vm, @idle_vm)
        @idle_vm.should_receive(:vm=).with(@vm)
        @idle_vm.should_receive(:current_state=).with({'state' => 'foo'})

        @resource_pool_updater.create_missing_vm(@idle_vm)
      end

      it 'should clean up the partially created VM' do
        agent = double(:AgentClient)
        agent.should_receive(:wait_until_ready).and_raise('timeout')
        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        @cloud.should_receive(:delete_vm).with('vm-1')

        lambda {
          @resource_pool_updater.create_missing_vm(@idle_vm)
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
        @resource_pool.stub(deployment_plan: deployment_plan)
        @resource_pool.stub(spec: resource_pool_spec)
        vm.stub(:update)
        agent.stub(:apply)
      end

      it 'sends the agent an updated state' do
        agent.should_receive(:apply).with(apply_spec)
        @resource_pool_updater.update_state(agent, vm, idle_vm)
      end

      it 'updates the vm model with the updated state' do
        vm.should_receive(:update).with(apply_spec: apply_spec)
        @resource_pool_updater.update_state(agent, vm, idle_vm)
      end
    end

    describe :delete_extra_vms
    describe :delete_outdated_idle_vms
    describe :reserve_networks
  end
end
