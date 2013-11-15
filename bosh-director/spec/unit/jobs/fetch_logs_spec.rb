# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::FetchLogs do
    let(:blobstore) { double('Blobstore') }

    before do
      @deployment = Models::Deployment.make
    end

    def make_job(instance_id)
      Jobs::FetchLogs.new(instance_id, blobstore: blobstore)
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :fetch_logs }
      it_behaves_like 'a Resque job'
    end

    it 'asks agent to fetch logs' do
      vm = Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      instance = Models::Instance.make(deployment: @deployment, vm: vm)

      job = make_job(instance.id)

      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)
      agent.should_receive(:fetch_logs).and_return('blobstore_id' => 'blobstore-id')

      job.should_receive(:with_deployment_lock).with(@deployment).and_yield
      job.perform.should == 'blobstore-id'
    end

    it "fails if instance doesn't reference vm" do
      instance = Models::Instance.make(deployment: @deployment, vm: nil, job: 'zb', index: '42')

      job = make_job(instance.id)
      job.should_receive(:with_deployment_lock).with(@deployment).and_yield

      expect {
        job.perform
      }.to raise_error(InstanceVmMissing, "`zb/42' doesn't reference a VM")
    end

    it 'keeps track of log bundles' do
      vm = Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      instance = Models::Instance.make(deployment: @deployment, vm: vm)
      job = make_job(instance.id)

      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)
      agent.should_receive(:fetch_logs).and_return('blobstore_id' => 'deadbeef')

      job.should_receive(:with_deployment_lock).with(@deployment).and_yield
      job.perform.should == 'deadbeef'

      Models::LogBundle.count.should == 1
      Models::LogBundle.filter(blobstore_id: 'deadbeef').count.should == 1
    end

    it 'cleans up old log bundles' do
      vm = Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      instance = Models::Instance.make(deployment: @deployment, vm: vm)
      job = make_job(instance.id)

      job.bundle_lifetime.should == 86400 * 10 # default lifetime
      job.bundle_lifetime = 0.01

      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)
      agent.should_receive(:fetch_logs).once.
        and_return('blobstore_id' => 'deadbeef1')

      job.should_receive(:with_deployment_lock).with(@deployment).and_yield
      job.perform.should == 'deadbeef1'
      Models::LogBundle.filter(blobstore_id: 'deadbeef1').count.should == 1

      agent.should_receive(:fetch_logs).once.
        and_return('blobstore_id' => 'deadbeef2')
      blobstore.should_receive(:delete).with('deadbeef1').and_return(true)

      sleep(0.05)
      job.should_receive(:with_deployment_lock).with(@deployment).and_yield
      job.perform.should == 'deadbeef2'

      Models::LogBundle.filter(blobstore_id: 'deadbeef1').count.should == 0
      Models::LogBundle.filter(blobstore_id: 'deadbeef2').count.should == 1
    end
  end
end
