# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe ProblemHandlers::UnresponsiveAgent do

    def make_handler(vm, cloud, agent, data = {})
      handler = ProblemHandlers::UnresponsiveAgent.new(vm.id, data)
      handler.stub(:cloud).and_return(cloud)
      AgentClient.stub(:with_defaults).with(vm.agent_id, anything).and_return(agent)
      handler
    end

    before(:each) do
      @cloud = instance_double('Bosh::Cloud')
      @agent = double('agent')
      Config.stub(:cloud).and_return(@cloud)

      @vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-007')
      @instance = Models::Instance.make(job: 'mysql_node', index: 0, vm_id: @vm.id)
    end

    let :handler do
      make_handler(@vm, @cloud, @agent)
    end

    it 'registers under unresponsive_agent type' do
      handler = ProblemHandlers::Base.create_by_type(:unresponsive_agent, @vm.id, {})
      handler.should be_kind_of(ProblemHandlers::UnresponsiveAgent)
    end

    it 'has well-formed description' do
      handler.description.should == 'mysql_node/0 (vm-cid) is not responding'
    end

    describe 'reboot_vm resolution' do
      it 'skips reboot if CID is not present' do
        @vm.update(cid: nil)
        @agent.should_receive(:ping).and_raise(RpcTimeout)
        lambda {
          handler.apply_resolution(:reboot_vm)
        }.should raise_error(ProblemHandlerError, /doesn't have a cloud id/)
      end

      it 'skips reboot if agent is now alive' do
        @agent.should_receive(:ping).and_return(:pong)

        lambda {
          handler.apply_resolution(:reboot_vm)
        }.should raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      it 'reboots VM' do
        @agent.should_receive(:ping).and_raise(RpcTimeout)
        @cloud.should_receive(:reboot_vm).with('vm-cid')
        @agent.should_receive(:wait_until_ready)

        handler.apply_resolution(:reboot_vm)
      end

      it 'reboots VM and whines if it is still unresponsive' do
        @agent.should_receive(:ping).and_raise(RpcTimeout)
        @cloud.should_receive(:reboot_vm).with('vm-cid')
        @agent.should_receive(:wait_until_ready).
          and_raise(RpcTimeout)

        lambda {
          handler.apply_resolution(:reboot_vm)
        }.should raise_error(ProblemHandlerError, 'Agent still unresponsive after reboot')
      end
    end

    describe 'recreate_vm resolution' do
      it 'skips recreate if CID is not present' do
        @vm.update(cid: nil)
        @agent.should_receive(:ping).and_raise(RpcTimeout)

        expect {
          handler.apply_resolution(:recreate_vm)
        }.to raise_error(ProblemHandlerError, /doesn't have a cloud id/)
      end

      it "doesn't recreate VM if agent is now alive" do
        @agent.stub(ping: :pong)

        expect {
          handler.apply_resolution(:recreate_vm)
        }.to raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      context 'when no errors' do
        let(:spec) do
          {
            'resource_pool' => {
              'stemcell' => {
                'name' => 'stemcell-name',
                'version' => '3.0.2'
              },
              'cloud_properties' => { 'foo' => 'bar' },
            },
            'networks' => ['A', 'B', 'C']
          }
        end
        let(:fake_new_agent) { double(Bosh::Director::AgentClient) }

        before do
          Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
          @vm.update(apply_spec: spec, env: { 'key1' => 'value1' })
          AgentClient.stub(:with_defaults).with('agent-222', anything).and_return(fake_new_agent)
          SecureRandom.stub(uuid: 'agent-222')
        end


        it 'recreates the VM' do
          @agent.stub(:ping).and_raise(RpcTimeout)

          @cloud.should_receive(:delete_vm).with('vm-cid')
          @cloud.
            should_receive(:create_vm).
            with('agent-222', 'sc-302', { 'foo' => 'bar' }, ['A', 'B', 'C'], [], { 'key1' => 'value1' })

          fake_new_agent.should_receive(:wait_until_ready).ordered
          fake_new_agent.should_receive(:apply).with(spec).ordered
          fake_new_agent.should_receive(:start).ordered

          Models::Vm.find(agent_id: 'agent-007').should_not be_nil

          handler.apply_resolution(:recreate_vm)

          Models::Vm.find(agent_id: 'agent-007').should be_nil
        end
      end
    end

    describe 'delete_vm_reference resolution' do
      it 'skips delete_vm_reference if CID is present' do
        @agent.should_receive(:ping).and_raise(RpcTimeout)
        expect {
          handler.apply_resolution(:delete_vm_reference)
        }.to raise_error(ProblemHandlerError, /has a cloud id/)
      end

      it 'skips deleting VM ref if agent is now alive' do
        @vm.update(cid: nil)
        @agent.should_receive(:ping).and_return(:pong)

        expect {
          handler.apply_resolution(:delete_vm_reference)
        }.to raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      it 'deletes VM reference' do
        @vm.update(cid: nil)
        @agent.should_receive(:ping).and_raise(RpcTimeout)
        handler.apply_resolution(:delete_vm_reference)
        Models::Vm[@vm.id].should be_nil
      end
    end
  end
end
