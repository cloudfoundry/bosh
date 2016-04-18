require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe Jobs::VmState do
    def stub_agent_get_state_to_return_state_with_vitals
      expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => {},
          'processes' => [
            {'name' => 'fake-process-1', 'state' => 'running'},
            {'name' => 'fake-process-2', 'state' => 'failing'},
          ],
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
      allow(Config).to receive(:dns).and_return({'domain_name' => 'microbosh', 'db' => {}})
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :vms }
      it_behaves_like 'a DJ job'
    end

    let(:instance) { Models::Instance.make(deployment: @deployment, agent_id: 'fake-agent-id', vm_cid: 'fake-vm-cid') }

    describe '#perform' do
      before { allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(anything, anything, timeout: 5).and_return(agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      it 'parses agent info into vm_state WITHOUT vitals' do
        instance  #trigger the let
        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => {}
        )

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['ips']).to eq(['1.1.1.1'])
          expect(status['dns']).to be_empty
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('running')
          expect(status['resource_pool']).to be_nil
          expect(status['vitals']).to be_nil
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'parses agent info into vm_state WITH vitals' do
        instance  #trigger the let
        stub_agent_get_state_to_return_state_with_vitals

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['ips']).to eq(['1.1.1.1'])
          expect(status['dns']).to be_empty
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('running')
          expect(status['resource_pool']).to be_nil
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
        instance.update(dns_record_names: ['index.job.network.deployment.microbosh'])

        stub_agent_get_state_to_return_state_with_vitals

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['dns']).to eq(['index.job.network.deployment.microbosh'])
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should return DNS A records ordered by instance id records first' do
        instance.update(dns_record_names: ['0.job.network.deployment.microbosh', 'd824057d-c92f-45a9-ad9f-87da12008b21.job.network.deployment.microbosh'])
        stub_agent_get_state_to_return_state_with_vitals

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['dns']).to eq(['d824057d-c92f-45a9-ad9f-87da12008b21.job.network.deployment.microbosh', '0.job.network.deployment.microbosh'])
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should handle unresponsive agents' do
        instance.update(resurrection_paused: true, job: 'dea', index: 50)

        expect(agent).to receive(:get_state).with('full').and_raise(RpcTimeout)

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('unresponsive agent')
          expect(status['resurrection_paused']).to be_truthy
          expect(status['job_name']).to eq('dea')
          expect(status['index']).to eq(50)
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should get the resurrection paused status' do
        instance.update(resurrection_paused: true)
        stub_agent_get_state_to_return_state_with_vitals
        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['resurrection_paused']).to be(true)
        end

        job.perform
      end

      it 'should return disk cid info when active disks found' do
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
        instance.update(uuid: 'blarg')
        stub_agent_get_state_to_return_state_with_vitals

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['id']).to eq('blarg')
        end

        job.perform
      end

      it 'should return vm_type' do
        instance.update(spec: {'vm_type' => {'name' => 'fake-vm-type', 'cloud_properties' => {}}})

        stub_agent_get_state_to_return_state_with_vitals

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['vm_type']).to eq('fake-vm-type')
        end

        job.perform
      end

      it 'should return processes info' do
        instance #trigger the let
        stub_agent_get_state_to_return_state_with_vitals

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'running' },
                {'name' => 'fake-process-2', 'state' => 'failing' }])
        end

        job.perform
      end

      context 'without vm_cid' do
        it 'does not try to contact the agent' do
          instance.update(vm_cid: nil)

          expect(@result_file).to receive(:write) do |agent_status|
            status = JSON.parse(agent_status)
            expect(status['job_state']).to eq(nil)
          end

          expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id)

          Jobs::VmState.new(@deployment.id, 'full', true).perform
        end
      end

      context 'when instance is a bootstrap node' do
        it 'should return bootstrap as true' do
          instance.update(bootstrap: true)
          stub_agent_get_state_to_return_state_with_vitals
          job = Jobs::VmState.new(@deployment.id, 'full')

          expect(@result_file).to receive(:write) do |agent_status|
            status = JSON.parse(agent_status)
            expect(status['bootstrap']).to be_truthy
          end

          job.perform
        end
      end

      context 'when instance is NOT a bootstrap node' do
        it 'should return bootstrap as false' do
          instance.update(bootstrap: false)
          stub_agent_get_state_to_return_state_with_vitals
          job = Jobs::VmState.new(@deployment.id, 'full')

          expect(@result_file).to receive(:write) do |agent_status|
            status = JSON.parse(agent_status)
            expect(status['bootstrap']).to be_falsey
          end

          job.perform
        end
      end

      it 'should return processes info' do
        instance.update(spec: {'vm_type' => {'name' => 'fake-vm-type', 'cloud_properties' => {}}})

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'index' => 0,
          'job' => { 'name' => 'dea' },
          'job_state' => 'running',
          'processes' => [
            {'name' => 'fake-process-1', 'state' => 'running' },
            {'name' => 'fake-process-2', 'state' => 'failing' },
          ],
          'resource_pool' => {}
        )

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['ips']).to eq(['1.1.1.1'])
          expect(status['vm_cid']).to eq('fake-vm-cid')
          expect(status['agent_id']).to eq('fake-agent-id')
          expect(status['job_state']).to eq('running')
          expect(status['resource_pool']).to eq('fake-vm-type')
          expect(status['vitals']).to be_nil
          expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'running' },
                                             {'name' => 'fake-process-2', 'state' => 'failing' }])
        end

        job.perform
      end

      context 'when exclude filter is set and vms without cid exist' do
        before(:each) do
          Models::Instance.make(deployment: @deployment, vm_cid: 'fake-vm-cid')
          Models::Instance.make(deployment: @deployment, vm_cid: nil)
        end

        it 'excludes them' do
          allow(agent).to receive(:get_state).with('full').and_return({
              'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          })
          job = Jobs::VmState.new(@deployment.id, 'full')

          expect(@result_file).to receive(:write).once

          job.perform
        end
      end
    end
  end
end
