require 'spec_helper'

module Bosh::Director
  describe AgentBroadcaster do
    let(:ip_addresses) { ['10.0.0.1'] }
    let(:vm1) { Bosh::Director::Models::Vm.make(id: 1, cid: 'id-1') }
    let(:vm2) { Bosh::Director::Models::Vm.make(id: 2, cid: 'id-2') }
    let(:instance1) do
      instance = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 1, job: 'fake-job-1')
      instance.add_vm(vm1)
      instance.update(active_vm: vm1)
    end
    let(:instance2) do
      instance = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 2, job: 'fake-job-1')
      instance.add_vm(vm2)
      instance.update(active_vm: vm2)
    end
    let(:agent) { double(AgentClient, wait_until_ready: nil, fake_method: nil, delete_arp_entries: nil) }
    let(:agent_broadcast) { AgentBroadcaster.new(0.1) }

    describe '#filter_instances' do
      it 'excludes the VM being created' do
        3.times do |i|
          Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}")
        end
        vm_being_created = Bosh::Director::Models::Vm.make(id: 11, cid: 'fake-cid-0')
        instance = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: 'fake-job-0')
        instance.add_vm(vm_being_created)
        instance.update(active_vm: vm_being_created)

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created.cid)

        expect(instances.count).to eq 0
      end

      it 'excludes instances where the vm is nil' do
        3.times do |i|
          Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}")
        end
        vm_being_created_cid = 'fake-cid-99'

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it 'excludes compilation VMs' do
        active_vm = Bosh::Director::Models::Vm.make(id: 11, cid: 'fake-cid-0')
        instance = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: 'fake-job-0', compilation: true)
        instance.add_vm(active_vm)
        instance.update(active_vm: active_vm)
        vm_being_created_cid = 'fake-cid-99'

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it 'includes VMs that need flushing' do
        active_vm = Bosh::Director::Models::Vm.make(id: 11, cid: 'fake-cid-0')
        instance = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: 'fake-job-0')
        instance.add_vm(active_vm)
        instance.update(active_vm: active_vm)
        vm_being_created_cid = 'fake-cid-99'

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances).to eq [instance]
      end
    end

    describe '#delete_arp_entries' do
      it 'successfully broadcast :delete_arp_entries call' do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance1.credentials, instance1.agent_id).and_return(agent)
        expect(agent).to receive(:send).with(:delete_arp_entries, ips: ip_addresses)

        agent_broadcast.delete_arp_entries('fake-vm-cid-to-exclude', ip_addresses)
      end

      it 'successfully filers out id-1 and broadcast :delete_arp_entries call' do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance1.credentials, instance1.agent_id).and_return(agent)
        expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id).
            with(instance2.credentials, instance2.agent_id)
        expect(agent).to receive(:delete_arp_entries).with(ips: ip_addresses)

        agent_broadcast.delete_arp_entries('id-2', ip_addresses)
      end
    end

    describe '#sync_dns' do
      context 'when all agents are responsive' do
        it 'successfully broadcast :sync_dns call' do
          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
              with(instance1.credentials, instance1.agent_id).and_return(agent)
          expect(agent).to receive(:send).with(:sync_dns, 'fake-blob-id', 'fake-sha1', 1) do |args, &blk|
            blk.call({'value' => 'synced'})
          end

          agent_broadcast.sync_dns('fake-blob-id', 'fake-sha1', 1)
        end
      end

      context 'when some agents fail' do
        let!(:instances) { [instance1, instance2]}

        context 'and agent succeeds within retry count' do
          it 'retries broadcasting to failed agents' do
            expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
                with(instance1.credentials, instance1.agent_id) do
              expect(agent).to receive(:sync_dns) do |*args, &blk|
                blk.call({'value' => 'synced'})
              end
              agent
            end
            expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
                with(instance2.credentials, instance2.agent_id) do
              expect(agent).to receive(:sync_dns)
              agent
            end.twice
            agent_broadcast.sync_dns('fake-blob-id', 'fake-sha1', 1)
          end
        end
      end
    end
  end
end
