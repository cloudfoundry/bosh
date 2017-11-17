require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe Jobs::VmState do
    def stub_agent_get_state_to_return_state_with_vitals
      expect(agent).to receive(:get_state).with('full').and_return(
        'vm_cid' => 'fake-vm-cid',
        'networks' => {'test' => {'ip' => '1.1.1.1'}},
        'agent_id' => 'fake-agent-id',
        'job_state' => 'running',
        'resource_pool' => {},
        'processes' => [
          {'name' => 'fake-process-1', 'state' => 'running'},
          {'name' => 'fake-process-2', 'state' => 'failing'},
        ],
        'cloud_properties' => {},
        'vitals' => {
          'load' => ['1', '5', '15'],
          'cpu' => {'user' => 'u', 'sys' => 's', 'wait' => 'w'},
          'mem' => {'percent' => 'p', 'kb' => 'k'},
          'swap' => {'percent' => 'p', 'kb' => 'k'},
          'disk' => {'system' => {'percent' => 'p'}, 'ephemeral' => {'percent' => 'p'}},
        },
      )
    end
    subject(:job) { Jobs::VmState.new(deployment.id, 'full', instance_details) }

    let(:instance_details) { false }
    let(:deployment) { Models::Deployment.make }
    let(:task) { Bosh::Director::Models::Task.make(:id => 42, :username => 'user') }
    let(:time) {Time.now}
    let(:vm) { Models::Vm.make(cid: 'fake-vm-cid', agent_id: 'fake-agent-id', instance_id: instance.id, created_at: time) }
    let(:instance) { Models::Instance.make(deployment: deployment) }

    before do
      allow(Config).to receive(:dns).and_return({'domain_name' => 'microbosh', 'db' => {}})
      allow(Config).to receive(:result).and_return(TaskDBWriter.new(:result_output, task.id))
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :vms }
      let(:queue) { :urgent }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do
      before do
        allow(AgentClient).to receive(:with_agent_id).with(anything, timeout: 5).and_return(agent)
        instance.active_vm = vm
        instance.save
      end

      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      it 'parses agent info into vm_state WITHOUT vitals' do
        Models::IpAddress.make(instance_id: instance.id, address_str: NetAddr::CIDR.create('1.1.1.1').to_i.to_s, task_id: '12345')
        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => {'test' => {'ip' => '1.1.1.1'}},
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => {}
        )

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['ips']).to eq(['1.1.1.1'])
        expect(status['dns']).to be_empty
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['agent_id']).to eq('fake-agent-id')
        expect(status['job_state']).to eq('running')
        expect(status['resource_pool']).to be_nil
        expect(status['vitals']).to be_nil
        expect(status['vm_created_at']).to eq(time.utc.iso8601)
      end

      context 'when there are two networks' do
        before {
          Models::IpAddress.make(instance_id: instance.id, address_str: NetAddr::CIDR.create('1.1.1.1').to_i.to_s, task_id: '12345')
          Models::IpAddress.make(instance_id: instance.id, address_str: NetAddr::CIDR.create('2.2.2.2').to_i.to_s, task_id: '12345')
        }

        it "returns the ip addresses from 'Models::Instance.ip_addresses'" do
          allow(agent).to receive(:get_state).with('full').and_raise(Bosh::Director::RpcTimeout)

          job.perform
          status = JSON.parse(Models::Task.first(id: task.id).result_output)
          expect(status['ips']).to eq(['1.1.1.1', '2.2.2.2'])
        end
      end

      context "when 'ip_addresses' is empty for instance" do
        before do
          instance.spec = {'networks' => {'a' => {'ip' => '1.1.1.1'}, 'b' => {'ip' => '2.2.2.2'}}}
          instance.save
        end

        it "returns the ip addresses from 'Models::Instance.apply_spec'" do
          allow(agent).to receive(:get_state).with('full').and_raise(Bosh::Director::RpcTimeout)

          job.perform

          status = JSON.parse(Models::Task.first(id: task.id).result_output)
          expect(status['ips']).to eq(['1.1.1.1', '2.2.2.2'])
        end
      end

      it 'parses agent info into vm_state WITH vitals' do
        Models::IpAddress.make(instance_id: instance.id, address_str: NetAddr::CIDR.create('1.1.1.1').to_i.to_s, task_id: '12345')
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['ips']).to eq(['1.1.1.1'])
        expect(status['dns']).to be_empty
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['agent_id']).to eq('fake-agent-id')
        expect(status['job_state']).to eq('running')
        expect(status['resource_pool']).to be_nil
        expect(status['vm_created_at']).to eq(time.utc.iso8601)
        expect(status['vitals']['load']).to eq(['1', '5', '15'])
        expect(status['vitals']['cpu']).to eq({'user' => 'u', 'sys' => 's', 'wait' => 'w'})
        expect(status['vitals']['mem']).to eq({'percent' => 'p', 'kb' => 'k'})
        expect(status['vitals']['swap']).to eq({'percent' => 'p', 'kb' => 'k'})
        expect(status['vitals']['disk']).to eq({'system' => {'percent' => 'p'}, 'ephemeral' => {'percent' => 'p'}})
      end

      it 'should return DNS A records if they exist' do
        instance.update(dns_record_names: ['index.job.network.deployment.microbosh'])

        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['dns']).to eq(['index.job.network.deployment.microbosh'])
      end

      it 'should return DNS A records ordered by instance id records first' do
        instance.update(dns_record_names: ['0.job.network.deployment.microbosh', 'd824057d-c92f-45a9-ad9f-87da12008b21.job.network.deployment.microbosh'])
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['dns']).to eq(['d824057d-c92f-45a9-ad9f-87da12008b21.job.network.deployment.microbosh', '0.job.network.deployment.microbosh'])
      end

      it 'should handle unresponsive agents' do
        instance.update(resurrection_paused: true, job: 'dea', index: 50)

        expect(agent).to receive(:get_state).with('full').and_raise(RpcTimeout)

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['vm_created_at']).to eq(time.utc.iso8601)
        expect(status['agent_id']).to eq('fake-agent-id')
        expect(status['job_state']).to eq('unresponsive agent')
        expect(status['resurrection_paused']).to be_truthy
        expect(status['job_name']).to eq('dea')
        expect(status['index']).to eq(50)
      end

      it 'should get the resurrection paused status' do
        instance.update(resurrection_paused: true)
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['resurrection_paused']).to be(true)
      end

      it 'should get the default ignore status of a vm' do
        instance
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['ignore']).to be(false)
      end

      it 'should get the ignore status of a vm when updated' do
        instance.update(ignore: true)
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['ignore']).to be(true)
      end

      it 'should return disk cid(s) info when active disks found' do
        Models::PersistentDisk.create(
          instance: instance,
          active: true,
          disk_cid: 'fake-disk-cid',
        )
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['disk_cid']).to eq('fake-disk-cid')
        expect(status['disk_cids']).to contain_exactly('fake-disk-cid')
      end

      it 'should return disk cid(s) info when many active disks found' do
        Models::PersistentDisk.create(
          instance: instance,
          active: true,
          disk_cid: 'fake-disk-cid',
        )
        Models::PersistentDisk.create(
          instance: instance,
          active: true,
          disk_cid: 'fake-disk-cid2',
        )

        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['disk_cid']).to eq('fake-disk-cid')
        expect(status['disk_cids']).to contain_exactly('fake-disk-cid', 'fake-disk-cid2')
      end

      it 'should return disk cid(s) info when NO active disks found' do
        Models::PersistentDisk.create(
          instance: instance,
          active: false,
          disk_cid: 'fake-disk-cid',
        )
        stub_agent_get_state_to_return_state_with_vitals


        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['disk_cid']).to be_nil
        expect(status['disk_cids']).to be_empty
      end

      it 'should return instance id' do
        instance.update(uuid: 'blarg')
        stub_agent_get_state_to_return_state_with_vitals


        job.perform
        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['id']).to eq('blarg')
      end

      it 'should return vm_type' do
        instance.update(spec: {'vm_type' => {'name' => 'fake-vm-type', 'cloud_properties' => {}}, 'networks' => []})

        stub_agent_get_state_to_return_state_with_vitals


        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['vm_type']).to eq('fake-vm-type')
      end

      it 'should return processes info' do
        instance #trigger the let
        stub_agent_get_state_to_return_state_with_vitals

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'running'},
          {'name' => 'fake-process-2', 'state' => 'failing'}])
      end

      context 'when including instances missing vms' do
        let(:instance_details) { true }

        it 'does not try to contact the agent' do
          instance.active_vm = nil

          expect(AgentClient).to_not receive(:with_agent_id)

          job.perform

          status = JSON.parse(Models::Task.first(id: task.id).result_output)
          expect(status['job_state']).to eq(nil)
        end
      end

      context 'when instance is a bootstrap node' do
        it 'should return bootstrap as true' do
          instance.update(bootstrap: true)
          stub_agent_get_state_to_return_state_with_vitals

          job.perform

          status = JSON.parse(Models::Task.first(id: task.id).result_output)
          expect(status['bootstrap']).to be_truthy
        end
      end

      context 'when instance is NOT a bootstrap node' do
        it 'should return bootstrap as false' do
          instance.update(bootstrap: false)
          stub_agent_get_state_to_return_state_with_vitals

          job.perform
          status = JSON.parse(Models::Task.first(id: task.id).result_output)
          expect(status['bootstrap']).to be_falsey
        end
      end

      it 'should return processes info' do
        Models::IpAddress.make(instance_id: instance.id, address_str: NetAddr::CIDR.create('1.1.1.1').to_i.to_s, task_id: '12345')
        instance.update(spec: {'vm_type' => {'name' => 'fake-vm-type', 'cloud_properties' => {}}})

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => {'test' => {'ip' => '1.1.1.1'}},
          'agent_id' => 'fake-agent-id',
          'index' => 0,
          'job' => {'name' => 'dea'},
          'job_state' => 'running',
          'processes' => [
            {'name' => 'fake-process-1', 'state' => 'running'},
            {'name' => 'fake-process-2', 'state' => 'failing'},
          ],
          'resource_pool' => {}
        )

        job.perform

        status = JSON.parse(Models::Task.first(id: task.id).result_output)
        expect(status['ips']).to eq(['1.1.1.1'])
        expect(status['vm_cid']).to eq('fake-vm-cid')
        expect(status['agent_id']).to eq('fake-agent-id')
        expect(status['job_state']).to eq('running')
        expect(status['resource_pool']).to eq('fake-vm-type')
        expect(status['vitals']).to be_nil
        expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'running'},
          {'name' => 'fake-process-2', 'state' => 'failing'}])
      end

      context 'with exclude filter and instances without vms' do
        it 'excludes those instances missing vms' do
          allow(agent).to receive(:get_state).with('full').and_return({
            'networks' => {'test' => {'ip' => '1.1.1.1'}},
          })

          expect(job.task_result).to receive(:write).once

          job.perform
        end
      end

      context 'when instance has multiple vms' do
        let!(:inactive_vm) { Models::Vm.make(instance: instance, active: false, agent_id: 'other_agent_id', cid: 'fake-vm-cid-2') }
        let(:lazy_agent) { instance_double('Bosh::Director::AgentClient') }

        before do
          Models::IpAddress.make(instance_id: instance.id, address_str: NetAddr::CIDR.create('1.1.1.1').to_i.to_s, task_id: '12345')
          allow(AgentClient).to receive(:with_agent_id).with('other_agent_id', timeout: 5).and_return(lazy_agent)
          allow(lazy_agent).to receive(:get_state).with('full').and_return(
            'vm_cid' => 'fake-vm-cid-2',
            'networks' => {'test' => {'ip' => '1.1.1.1'}},
            'agent_id' => 'other_agent_id',
            'index' => 0,
            'job' => {'name' => 'dea'},
            'job_state' => 'stopped',
            'processes' => [
              {'name' => 'fake-process-1', 'state' => 'stopped'},
              {'name' => 'fake-process-2', 'state' => 'stopped'},
            ],
            'resource_pool' => {}
          )
          allow(agent).to receive(:get_state).with('full').and_return(
            'vm_cid' => 'fake-vm-cid',
            'networks' => {'test' => {'ip' => '1.1.1.1'}},
            'agent_id' => 'fake-agent-id',
            'index' => 0,
            'job' => {'name' => 'dea'},
            'job_state' => 'running',
            'processes' => [
              {'name' => 'fake-process-1', 'state' => 'running'},
              {'name' => 'fake-process-2', 'state' => 'failing'},
            ],
            'resource_pool' => {}
          )
          instance.update(spec: {'vm_type' => {'name' => 'fake-vm-type', 'cloud_properties' => {}}})
        end

        context 'when getting vm states' do
          it 'returns all vms, active and inactive' do
            job.perform
            results = Models::Task.first(id: task.id).result_output.split("\n")

            expect(results.length).to eq(2)
            status = JSON.parse(results[0])
            expect(status['ips']).to eq(['1.1.1.1'])
            expect(status['vm_cid']).to eq('fake-vm-cid')
            expect(status['agent_id']).to eq('fake-agent-id')
            expect(status['job_state']).to eq('running')
            expect(status['resource_pool']).to eq('fake-vm-type')
            expect(status['vitals']).to be_nil
            expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'running'},
              {'name' => 'fake-process-2', 'state' => 'failing'}])

            status = JSON.parse(results[1])
            expect(status['ips']).to eq(['1.1.1.1'])
            expect(status['vm_cid']).to eq('fake-vm-cid-2')
            expect(status['agent_id']).to eq('other_agent_id')
            expect(status['job_state']).to eq('stopped')
            expect(status['resource_pool']).to eq('fake-vm-type')
            expect(status['vitals']).to be_nil
            expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'stopped'},
              {'name' => 'fake-process-2', 'state' => 'stopped'}])
          end
        end

        context 'when getting instance states' do
          let(:instance_details) { true }

          it 'returns information from active vm' do
            job.perform
            results = Models::Task.first(id: task.id).result_output.split("\n")

            expect(results.length).to eq(1)
            status = JSON.parse(results[0])
            expect(status['ips']).to eq(['1.1.1.1'])
            expect(status['vm_cid']).to eq('fake-vm-cid')
            expect(status['agent_id']).to eq('fake-agent-id')
            expect(status['job_state']).to eq('running')
            expect(status['resource_pool']).to eq('fake-vm-type')
            expect(status['vitals']).to be_nil
            expect(status['processes']).to eq([{'name' => 'fake-process-1', 'state' => 'running'},
              {'name' => 'fake-process-2', 'state' => 'failing'}])
          end
        end
      end
    end
  end
end
