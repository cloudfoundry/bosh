# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe Jobs::VmState do
    before do
      @deployment = Models::Deployment.make
      @result_file = double('result_file')
      Config.stub(:result).and_return(@result_file)
      Config.stub(:dns_domain_name).and_return('microbosh')
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :vms }
      it_behaves_like 'a Resque job'
    end

    it 'parses agent info into vm_state' do
      Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1', timeout: 5).and_return(agent)
      agent_state = {'vm_cid' => 'vm-1',
                     'networks' => {'test' => {'ip' => '1.1.1.1'}},
                     'agent_id' => 'agent-1',
                     'job_state' => 'running',
                     'resource_pool' => {'name' => 'test_resource_pool'}}
      agent.should_receive(:get_state).and_return(agent_state)

      @result_file.should_receive(:write) do |agent_status|
        status = JSON.parse(agent_status)
        status['ips'].should == ['1.1.1.1']
        status['dns'].should be_empty
        status['vm_cid'].should == 'vm-1'
        status['agent_id'].should == 'agent-1'
        status['job_state'].should == 'running'
        status['resource_pool'].should == 'test_resource_pool'
        status['vitals'].should be_nil
      end

      job = Jobs::VmState.new(@deployment.id, nil)
      job.perform
    end

    it 'parses agent info into vm_state with vitals' do
      Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1', timeout: 5).and_return(agent)

      agent_state = {'vm_cid' => 'vm-1',
                     'networks' => {'test' => {'ip' => '1.1.1.1'}},
                     'agent_id' => 'agent-1',
                     'job_state' => 'running',
                     'resource_pool' => {'name' => 'test_resource_pool'},
                     'vitals' => {
                       'load' => ['1', '5', '15'],
                       'cpu' => {'user' => 'u', 'sys' => 's', 'wait' => 'w'},
                       'mem' => {'percent' => 'p', 'kb' => 'k'},
                       'swap' => {'percent' => 'p', 'kb' => 'k'},
                       'disk' => {'system' => {'percent' => 'p'},
                                  'ephemeral' => {'percent' => 'p'}
                       }
                     }
      }
      agent.should_receive(:get_state).and_return(agent_state)

      @result_file.should_receive(:write) do |agent_status|
        status = JSON.parse(agent_status)
        status['ips'].should == ['1.1.1.1']
        status['dns'].should be_empty
        status['vm_cid'].should == 'vm-1'
        status['agent_id'].should == 'agent-1'
        status['job_state'].should == 'running'
        status['resource_pool'].should == 'test_resource_pool'
        status['vitals']['load'].should == ['1', '5', '15']
        status['vitals']['cpu'].should == {'user' => 'u', 'sys' => 's', 'wait' => 'w'}
        status['vitals']['mem'].should == {'percent' => 'p', 'kb' => 'k'}
        status['vitals']['swap'].should == {'percent' => 'p', 'kb' => 'k'}
        status['vitals']['disk'].should == {'system' => {'percent' => 'p'},
                                            'ephemeral' => {'percent' => 'p'}}
      end

      job = Jobs::VmState.new(@deployment.id, 'full')
      job.perform
    end

    it 'should return DNS A records if they exist' do
      Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      domain = Models::Dns::Domain.make(name: 'microbosh', type: 'NATIVE')
      Models::Dns::Record.make(domain: domain, 
                               name: 'index.job.network.deployment.microbosh',
                               type: 'A', 
                               content: '1.1.1.1', 
                               ttl: 14400)
      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1', timeout: 5).and_return(agent)
      agent_state = {'vm_cid' => 'vm-1',
                     'networks' => {'test' => {'ip' => '1.1.1.1'}},
                     'agent_id' => 'agent-1',
                     'job_state' => 'running',
                     'resource_pool' => {'name' => 'test_resource_pool'}}
      agent.should_receive(:get_state).and_return(agent_state)

      @result_file.should_receive(:write) do |agent_status|
        status = JSON.parse(agent_status)
        status['ips'].should == ['1.1.1.1']
        status['dns'].should == ['index.job.network.deployment.microbosh']
        status['vm_cid'].should == 'vm-1'
        status['agent_id'].should == 'agent-1'
        status['job_state'].should == 'running'
        status['resource_pool'].should == 'test_resource_pool'
        status['vitals'].should be_nil
      end

      job = Jobs::VmState.new(@deployment.id, nil)
      job.perform
    end

    it 'should handle unresponsive agents' do
      Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1', timeout: 5).and_return(agent)
      agent.should_receive(:get_state).and_raise(RpcTimeout)

      @result_file.should_receive(:write) do |agent_status|
        status = JSON.parse(agent_status)
        status['vm_cid'].should == 'vm-1'
        status['agent_id'].should == 'agent-1'
        status['job_state'].should == 'unresponsive agent'
        status['resurrection_paused'].should be_nil
      end

      job = Jobs::VmState.new(@deployment.id, nil)
      job.perform
    end

    it 'should get the resurrection paused status' do
      Models::Instance.create(deployment: @deployment,
                              job: 'dea',
                              index: '0',
                              state: 'started',
                              resurrection_paused: true)
      Models::Vm.make(deployment: @deployment, agent_id: 'agent-1', cid: 'vm-1')
      agent = double('agent')
      AgentClient.stub(:with_defaults).with('agent-1', timeout: 5).and_return(agent)

      agent_state = {'vm_cid' => 'vm-1',
                     'networks' => {'test' => {'ip' => '1.1.1.1'}},
                     'agent_id' => 'agent-1',
                     'index' => 0,
                     'job' => {'name' => 'dea'},
                     'job_state' => 'running',
                     'resource_pool' => {'name' => 'test_resource_pool'},
                     'vitals' => {
                       'load' => ['1', '5', '15'],
                       'cpu' => {'user' => 'u', 'sys' => 's', 'wait' => 'w'},
                       'mem' => {'percent' => 'p', 'kb' => 'k'},
                       'swap' => {'percent' => 'p', 'kb' => 'k'},
                       'disk' => {'system' => {'percent' => 'p'},
                                  'ephemeral' => {'percent' => 'p'}
                       }
                     }
      }
      agent.should_receive(:get_state).and_return(agent_state)

      job = Jobs::VmState.new(@deployment.id, 'full')

      @result_file.should_receive(:write) do |agent_status|
        status = JSON.parse(agent_status)
        expect(status['resurrection_paused']).to be(true)
      end

      job.perform
    end
  end
end
