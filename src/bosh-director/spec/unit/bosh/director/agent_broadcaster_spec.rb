require 'spec_helper'

module Bosh::Director
  describe AgentBroadcaster do
    let(:ip_addresses) { ['10.0.0.1'] }
    let(:instance1) do
      FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: 1, job: 'fake-job-1').tap do |i|
        FactoryBot.create(:models_vm, id: 1, agent_id: 'agent-1', cid: 'id-1', instance_id: i.id, active: true, stemcell_api_version: 3)
      end.reload
    end
    let(:instance2) do
      FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: 2, job: 'fake-job-1').tap do |i|
        FactoryBot.create(:models_vm, id: 2, agent_id: 'agent-2', cid: 'id-2', instance_id: i.id, active: true)
      end.reload
    end
    let(:agent) { instance_double(AgentClient, wait_until_ready: nil, delete_arp_entries: nil) }
    let(:agent2) { instance_double(AgentClient, wait_until_ready: nil, delete_arp_entries: nil) }
    let(:agent_broadcast) { AgentBroadcaster.new(0.1) }
    let(:blobstore) { instance_double(Bosh::Director::Blobstore::Client) }

    before do
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(blobstore).to receive(:can_sign_urls?).and_return(false)
    end

    describe '#filter_instances' do
      it 'excludes the VM being created' do
        3.times do |i|
          FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}")
        end

        instance = FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: 0, job: 'fake-job-0')
        vm_being_created = FactoryBot.create(:models_vm, id: 11, cid: 'fake-cid-0', instance_id: instance.id, active: true)

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created.cid)

        expect(instances.count).to eq 0
      end

      it 'excludes instances where the vm is nil' do
        3.times do |i|
          FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}")
        end
        vm_being_created_cid = 'fake-cid-99'

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it 'excludes compilation VMs' do
        instance = FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: 0, job: 'fake-job-0', compilation: true)
        active_vm = FactoryBot.create(:models_vm, id: 11, cid: 'fake-cid-0', instance:, active: true)
        vm_being_created_cid = 'fake-cid-99'

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it 'includes VMs that need flushing' do
        instance = FactoryBot.create(:models_instance, uuid: SecureRandom.uuid, index: 0, job: 'fake-job-0')
        active_vm = FactoryBot.create(:models_vm, id: 11, cid: 'fake-cid-0', instance:, active: true)
        vm_being_created_cid = 'fake-cid-99'

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.map(&:id)).to eq [instance.id]
      end
    end

    describe '#delete_arp_entries' do
      it 'successfully broadcast :delete_arp_entries call' do
        expect(AgentClient).to receive(:with_agent_id)
          .with(instance1.agent_id, instance1.name).and_return(agent)
        expect(agent).to receive(:delete_arp_entries).with(ips: ip_addresses)

        agent_broadcast.delete_arp_entries('fake-vm-cid-to-exclude', ip_addresses)
      end

      it 'successfully filers out id-1 and broadcast :delete_arp_entries call' do
        expect(AgentClient).to receive(:with_agent_id)
          .with(instance1.agent_id, instance1.name).and_return(agent)
        expect(AgentClient).to_not receive(:with_agent_id)
          .with(instance2.agent_id, instance2.name)
        expect(agent).to receive(:delete_arp_entries).with(ips: ip_addresses)

        agent_broadcast.delete_arp_entries('id-2', ip_addresses)
      end
    end

    describe '#sync_dns' do
      let(:start_time) { Time.now }
      let(:end_time) { start_time + 0.01 }

      before do
        Timecop.freeze(start_time)
      end

      context 'when all agents are responsive' do
        it 'successfully broadcast :sync_dns call' do
          expect(per_spec_logger).to receive(:info).with('agent_broadcaster: sync_dns: sending to 2 agents ["agent-1", "agent-2"]')
          expect(per_spec_logger).to receive(:info).with('agent_broadcaster: sync_dns: attempted 2 agents in 10ms (2 successful, 0 failed, 0 unresponsive)')

          expect(AgentClient).to receive(:with_agent_id)
            .with(instance1.agent_id, instance1.name).and_return(agent)

          expect(agent).to receive(:sync_dns).with('fake-blob-id', 'fake-sha1', 1) do |&blk|
            blk.call('value' => 'synced')
            Timecop.freeze(end_time)
          end.and_return('instance-1-req-id')

          expect(AgentClient).to receive(:with_agent_id)
            .with(instance2.agent_id, instance2.name).and_return(agent2)

          expect(agent2).to receive(:sync_dns).with('fake-blob-id', 'fake-sha1', 1) do |&blk|
            blk.call('value' => 'synced')
          end.and_return('instance-2-req-id')

          agent_broadcast.sync_dns([instance1, instance2], 'fake-blob-id', 'fake-sha1', 1)

          expect(Models::AgentDnsVersion.all.length).to eq(2)
        end
      end

      context 'when some agents fail' do
        let!(:instances) { [instance1, instance2] }

        context 'and agent succeeds within retry count' do
          it 'retries broadcasting to failed agents' do
            expect(per_spec_logger).to receive(:info).with('agent_broadcaster: sync_dns: sending to 2 agents ["agent-1", "agent-2"]')
            expect(per_spec_logger).to receive(:error).with('agent_broadcaster: sync_dns[agent-2]: received unexpected response {"value"=>"unsynced"}')
            expect(per_spec_logger).to receive(:info).with('agent_broadcaster: sync_dns: attempted 2 agents in 10ms (1 successful, 1 failed, 0 unresponsive)')

            expect(AgentClient).to receive(:with_agent_id)
              .with(instance1.agent_id, instance1.name) do
              expect(agent).to receive(:sync_dns) do |&blk|
                blk.call('value' => 'synced')
                Timecop.freeze(end_time)
              end
              agent
            end

            expect(AgentClient).to receive(:with_agent_id)
              .with(instance2.agent_id, instance2.name) do
              expect(agent).to receive(:sync_dns) do |&blk|
                blk.call('value' => 'unsynced')
              end
              agent
            end

            agent_broadcast.sync_dns(instances, 'fake-blob-id', 'fake-sha1', 1)

            expect(Models::AgentDnsVersion.all.length).to eq(1)
          end
        end
      end

      context 'that we are able to update the AgentDnsVersion' do
        let!(:instances) { [instance1] }

        before do
          expect(AgentClient).to receive(:with_agent_id) do
            expect(agent).to receive(:sync_dns) do |&blk|
              blk.call('value' => 'synced')
              Timecop.freeze(end_time)
            end
            agent
          end
        end

        context 'when there are no prior existing records for the instances' do
          it 'will create new records for the instances' do
            agent_broadcast.sync_dns(instances, 'fake-blob-id', 'fake-sha1', 42)

            expect(Models::AgentDnsVersion.all.length).to eq(1)
            expect(Models::AgentDnsVersion.all[0].dns_version).to equal(42)
          end
        end

        context 'when we need to update existing records for the instances' do
          before do
            Models::AgentDnsVersion.create(agent_id: instance1.agent_id, dns_version: 1)
          end

          it 'will update records for the instances' do
            agent_broadcast.sync_dns(instances, 'fake-blob-id', 'fake-sha1', 42)

            expect(Models::AgentDnsVersion.all.length).to eq(1)
            expect(Models::AgentDnsVersion.all[0].dns_version).to equal(42)
          end
        end

        context 'when another thread would have inserted the instance at the same time' do
          before do
            # placeholder since we override the create method in the next line
            version = Models::AgentDnsVersion.create(agent_id: 'fake-agent', dns_version: 1)

            expect(Models::AgentDnsVersion).to receive(:create) do
              # pretend another parallel process inserted an agent record in the db to emulate the race
              version.agent_id = instance1.agent_id
              version.save

              raise Sequel::UniqueConstraintViolation
            end
          end

          it 'will still be able to update the AgentDnsVersion records' do
            agent_broadcast.sync_dns(instances, 'fake-blob-id', 'fake-sha1', 42)

            expect(Models::AgentDnsVersion.all[0].dns_version).to equal(42)
          end
        end
      end

      context 'when some agents are unresponsive' do
        let!(:instances) { [instance1, instance2] }

        context 'and agent succeeds within retry count' do
          it 'logs broadcasting fail to failed agents' do
            expect(per_spec_logger).to receive(:info).with('agent_broadcaster: sync_dns: sending to 2 agents ["agent-1", "agent-2"]')
            expect(per_spec_logger).to receive(:warn).with('agent_broadcaster: sync_dns: no response received for 1 agent(s): [agent-2]')
            expect(per_spec_logger).to receive(:info).with(/agent_broadcaster: sync_dns: attempted 2 agents in \d+ms \(1 successful, 0 failed, 1 unresponsive\)/)

            expect(AgentClient).to receive(:with_agent_id)
              .with(instance1.agent_id, instance1.name) do
              expect(agent).to receive(:sync_dns) do |&blk|
                blk.call('value' => 'synced')
                Timecop.travel(end_time)
              end.and_return('sync_dns_request_id_1')
              agent
            end

            expect(AgentClient).to receive(:with_agent_id)
              .with(instance2.agent_id, instance2.name) do
              expect(agent).to receive(:sync_dns).and_return('sync_dns_request_id_2')
              agent
            end.once

            expect(AgentClient).to receive(:with_agent_id)
              .with(instance2.agent_id, instance2.name) do
              expect(agent).to receive(:cancel_sync_dns).with('sync_dns_request_id_2')
              agent
            end.once

            agent_broadcast.sync_dns(instances, 'fake-blob-id', 'fake-sha1', 1)

            expect(Models::AgentDnsVersion.all.length).to eq(1)
          end
        end
      end

      context 'only after all messages have been sent off' do
        it 'starts the timeout timer' do
          expect(AgentClient).to receive(:with_agent_id) do
            allow(agent).to receive(:sync_dns) do |&blk|
              blk.call('value' => 'synced')
            end
            agent
          end.ordered
          expect(Timeout).to receive(:new).and_call_original.ordered

          agent_broadcast.sync_dns([instance1], 'fake-blob-id', 'fake-sha1', 1)
        end
      end

      context 'when blobstore and instance are capable of using signed urls' do
        before do
          allow(blobstore).to receive(:can_sign_urls?).and_return(true)
          allow(blobstore).to receive(:headers).and_return({})
        end

        it 'signs the existing blobstore id' do
          expect(blobstore).to receive(:can_sign_urls?).with(3)
          expect(blobstore).to receive(:sign).with('fake-blob-id').and_return('signed')
          expect(AgentClient).to receive(:with_agent_id).with(instance1.agent_id, instance1.name) do
            expect(agent).to receive(:sync_dns_with_signed_url).with({
              'signed_url' => 'signed',
              'multi_digest' => 'fake-sha1',
              'version' => anything,
            }) do |&blk|
              blk.call('value' => 'synced')
              Timecop.freeze(end_time)
            end
            agent
          end

          agent_broadcast.sync_dns([instance1], 'fake-blob-id', 'fake-sha1', 1)
        end

        context 'and encryption is enabled' do
          before do
            allow(blobstore).to receive(:headers).and_return({ 'header' => 'value' })
            allow(blobstore).to receive(:sign).with('fake-blob-id').and_return('signed')
          end

          it 'adds headers to the request' do
            expect(AgentClient).to receive(:with_agent_id).with(instance1.agent_id, instance1.name) do
              expect(agent).to receive(:sync_dns_with_signed_url).with({
                'signed_url' => 'signed',
                'multi_digest' => 'fake-sha1',
                'version' => 1,
                'blobstore_headers' => { 'header' => 'value' },
              }) do |&blk|
                blk.call('value' => 'synced')
                Timecop.freeze(end_time)
              end
              agent
            end

            agent_broadcast.sync_dns([instance1], 'fake-blob-id', 'fake-sha1', 1)
          end
        end
      end
    end
  end
end
