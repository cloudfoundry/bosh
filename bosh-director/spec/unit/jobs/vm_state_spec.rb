require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe Jobs::VmState do
    def stub_agent_get_state_to_return_state_with_vitals
      expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'index' => 0,
          'job' => { 'name' => 'dea' },
          'job_state' => 'running',
          'resource_pool' => { 'name' => 'test_resource_pool' },
          'vitals' => {
            'load' => ['1', '5', '15'],
            'cpu' => { 'user' => 'u', 'sys' => 's', 'wait' => 'w' },
            'mem' => { 'percent' => 'p', 'kb' => 'k' },
            'swap' => { 'percent' => 'p', 'kb' => 'k' },
            'disk' => { 'system' => { 'percent' => 'p' }, 'ephemeral' => { 'percent' => 'p' } },
          },
        )
    end

    before do
      @deployment = Models::Deployment.make
      @result_file = double('result_file')
      allow(Config).to receive(:result).and_return(@result_file)
      allow(Config).to receive(:dns_domain_name).and_return('microbosh')
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :vms }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      before { allow(AgentClient).to receive(:with_vm).with(instance_of(Models::Vm), timeout: 5).and_return(agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      it 'parses agent info into vm_state WITHOUT vitals' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => { 'name' => 'test_resource_pool' },
        )

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['ips']).to eq(['1.1.1.1'])
          expect(status['dns']).to be_empty
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('running')
          expect(status['resource_pool']).to eq('test_resource_pool')
          expect(status['vitals']).to be_nil
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'parses agent info into vm_state WITH vitals' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
        stub_agent_get_state_to_return_state_with_vitals

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['ips']).to eq(['1.1.1.1'])
          expect(status['dns']).to be_empty
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('running')
          expect(status['resource_pool']).to eq('test_resource_pool')
          expect(status['vitals']['load']).to eq(['1', '5', '15'])
          expect(status['vitals']['cpu']).to eq({ 'user' => 'u', 'sys' => 's', 'wait' => 'w' })
          expect(status['vitals']['mem']).to eq({ 'percent' => 'p', 'kb' => 'k' })
          expect(status['vitals']['swap']).to eq({ 'percent' => 'p', 'kb' => 'k' })
          expect(status['vitals']['disk']).to eq({ 'system' => { 'percent' => 'p' }, 'ephemeral' => { 'percent' => 'p' } })
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should return DNS A records if they exist' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
        domain = Models::Dns::Domain.make(name: 'microbosh', type: 'NATIVE')
        Models::Dns::Record.make(
          domain: domain,
          name: 'index.job.network.deployment.microbosh',
          type: 'A',
          content: '1.1.1.1',
          ttl: 14400,
        )
        stub_agent_get_state_to_return_state_with_vitals

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['dns']).to eq(['index.job.network.deployment.microbosh'])
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should handle unresponsive agents' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        expect(agent).to receive(:get_state).with('full').and_raise(RpcTimeout)

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('unresponsive agent')
          expect(status['resurrection_paused']).to be_nil
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should get the resurrection paused status' do
        vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
        Models::Instance.create(
          deployment: @deployment,
          job: 'dea',
          index: '0',
          state: 'started',
          resurrection_paused: true,
          vm: vm,
        )
        stub_agent_get_state_to_return_state_with_vitals
        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['resurrection_paused']).to be(true)
        end

        job.perform
      end

      it 'should return disk cid info when active disks found' do
        vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
        instance = Models::Instance.create(
          deployment: @deployment,
          job: 'dea',
          index: '0',
          state: 'started',
          vm: vm,
        )
        Models::PersistentDisk.create(
          instance: instance,
          active: true,
          disk_cid: 'fake-disk-cid',
        )
        stub_agent_get_state_to_return_state_with_vitals
        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['disk_cid']).to eq('fake-disk-cid')
        end

        job.perform
      end

      it 'should return disk cid info when NO active disks found' do
        vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
        instance = Models::Instance.create(
          deployment: @deployment,
          job: 'dea',
          index: '0',
          state: 'started',
          vm: vm,
        )
        Models::PersistentDisk.create(
          instance: instance,
          active: false,
          disk_cid: 'fake-disk-cid',
        )
        stub_agent_get_state_to_return_state_with_vitals

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['disk_cid']).to be_nil
        end

        job.perform

      end

      it 'should return instance id' do
        vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
        Models::Instance.create(
          deployment: @deployment,
          job: 'dea',
          index: '0',
          state: 'started',
          resurrection_paused: true,
          vm: vm,
          uuid: 'blarg'
        )
        stub_agent_get_state_to_return_state_with_vitals

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['instance_id']).to eq('blarg')
        end

        job.perform
      end

      context 'when instance is a bootstrap node' do
        it 'should return is_bootstrap as true' do
          vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
          Models::Instance.create(
            deployment: @deployment,
            job: 'dea',
            index: '0',
            state: 'started',
            resurrection_paused: true,
            vm: vm,
            uuid: 'blarg',
            bootstrap: true
          )
          stub_agent_get_state_to_return_state_with_vitals
          job = Jobs::VmState.new(@deployment.id, 'full')

          expect(@result_file).to receive(:write) do |agent_status|
            status = JSON.parse(agent_status)
            expect(status['is_bootstrap']).to be_truthy
          end

          job.perform
        end
      end

      context 'when instance is NOT a bootstrap node' do
        it 'should return is_bootstrap as false' do
          vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')
          Models::Instance.create(
            deployment: @deployment,
            job: 'dea',
            index: '1',
            state: 'started',
            resurrection_paused: true,
            vm: vm,
            uuid: 'blarg'
          )
          stub_agent_get_state_to_return_state_with_vitals
          job = Jobs::VmState.new(@deployment.id, 'full')

          expect(@result_file).to receive(:write) do |agent_status|
            status = JSON.parse(agent_status)
            expect(status['is_bootstrap']).to be_falsey
          end

          job.perform
        end
      end
    end

    describe '#process_vm' do
      before { allow(AgentClient).to receive(:with_vm).with(instance_of(Models::Vm), timeout: 5).and_return(agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      context 'when job index returned as part of get_state agent response is an empty string' do
        let(:vm) { Models::Vm.make(agent_id: 'fake-agent-id', cid: 'fake-vm-cid', deployment: @deployment) }

        # This test only makes sense for Postgres DB because it used to raise following error:
        #   #<Sequel::DatabaseError: PG::Error: ERROR:  invalid input syntax for integer: ""
        #   LINE 1: ..._id" = 8) AND ("job" = 'fake job') AND ("index" = '')) LIMIT...
        it 'does not raise Sequel::DatabaseError' do
          expect(agent).to receive(:get_state).with('full').and_return(
            'vm_cid' => 'fake vm',
            'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
            'agent_id' => 'fake-agent-id',
            'index' => '',
            'job' => { 'name' => 'fake job' },
          )

          job = Jobs::VmState.new(@deployment.id, 'full')

          expect { job.process_vm(vm) }.to_not raise_error
        end
      end
    end
  end
end
