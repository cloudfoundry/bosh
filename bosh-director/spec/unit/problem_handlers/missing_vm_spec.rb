# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe ProblemHandlers::MissingVM do

    let(:vm) { Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-007') }
    let(:handler) { ProblemHandlers::Base.create_by_type(:missing_vm, vm.id, {}) }

    it 'registers under missing_vm type' do
      handler.should be_kind_of(described_class)
    end

    it 'has description' do
      handler.description.should =~ /VM with cloud ID `vm-cid' missing./
    end

    describe 'Resolutions:' do
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
      let(:fake_cloud) { instance_double('Bosh::Cloud') }
      let(:fake_new_agent) { double('Bosh::Director::AgentClient') }

      def fake_job_context
        handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
        Config.stub(cloud: fake_cloud)
      end

      it 'recreates a VM' do
        vm.update(:apply_spec => spec, env: { 'key1' => 'value1' })
        Models::Instance.make(job: 'mysql_node', index: 0, vm_id: vm.id)
        Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')

        SecureRandom.stub(uuid: 'agent-222')
        AgentClient.stub(:with_defaults).with('agent-222', anything).and_return(fake_new_agent)

        fake_new_agent.should_receive(:wait_until_ready).ordered
        fake_new_agent.should_receive(:apply).with(spec).ordered
        fake_new_agent.should_receive(:start).ordered

        fake_cloud.should_receive(:delete_vm).with('vm-cid')
        fake_cloud.
          should_receive(:create_vm).
          with('agent-222', 'sc-302', { 'foo' => 'bar' }, ['A', 'B', 'C'], [], { 'key1' => 'value1' })

        fake_job_context

        expect {
          handler.apply_resolution(:recreate_vm)
        }.to change { Models::Vm.where(agent_id: 'agent-007').count }.from(1).to(0)
      end

      it 'deletes VM reference' do
        handler.apply_resolution(:delete_vm_reference)
        Models::Vm[vm.id].should be_nil
      end
    end
  end
end
