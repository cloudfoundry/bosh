require 'spec_helper'

module Bosh::Director
  describe DnsUpdater do
    subject(:dns_updater) { DnsUpdater.new(logger) }
    let(:agent_client) { double(AgentClient) }
    let(:credentials) { {'creds' => 'hash'} }
    let(:credentials_json) { JSON.generate(credentials) }
    let(:blob_sha1) { ::Digest::SHA1.hexdigest('dns-records') }
    let(:logger) { double(Logger)}
    let!(:local_dns_blob) do
      Models::LocalDnsBlob.make(
        blobstore_id: 'blob-id',
        sha1: blob_sha1,
        version: 2,
        created_at: Time.new)
    end

    before do
      allow(logger).to receive(:info)
    end

    describe '#update_dns_for_instance' do
      let(:instance) do
        instance = Models::Instance.make
        Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid', instance_id: instance.id, active: true)
        instance
      end

      context 'when sync_dns call returns synced value' do
        let(:agent_message) { {'value' => 'synced'} }

        it 'logs success and updates the AgentDnsVersion' do
          Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)

          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance.agent_id) do
            expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
              expect(blobstore_id).to eq('blob-id')
              expect(sha1).to eq(blob_sha1)
              expect(version).to eq(2)
              blk.call(agent_message)
            end
            agent_client
          end

          expect(logger).to receive(:info).with("Successfully updated instance '#{instance}' with agent id '#{instance.agent_id}' to dns version #{local_dns_blob.version}. agent sync_dns response: '#{agent_message}'")

          dns_updater.update_dns_for_instance(local_dns_blob, instance)

          expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(2)
        end

        it 'updates agents that have no agent dns record' do
          instance = Models::Instance.make
          Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid', instance_id: instance.id, active: true)

          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(credentials, 'abc') do
            expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
              expect(blobstore_id).to eq('blob-id')
              expect(sha1).to eq(blob_sha1)
              expect(version).to eq(2)
              blk.call({'value' => 'synced'})
            end
            agent_client
          end

          dns_updater.update_dns_for_instance(local_dns_blob, instance)

          expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(2)
        end
      end

      context 'when sync_dns call fails' do
        let(:agent_message) { {'value' => 'failed'} }

        it 'logs failure and does not update AgentDnsVersion for instance' do
          Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)

          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance.agent_id) do
            expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
              expect(blobstore_id).to eq('blob-id')
              expect(sha1).to eq(blob_sha1)
              expect(version).to eq(2)
              blk.call(agent_message)
            end
            agent_client
          end

          expect(logger).to receive(:info).with("Failed to update instance '#{instance}' with agent id '#{instance.agent_id}' to dns version #{local_dns_blob.version}. agent sync_dns response: '#{agent_message}'")

          dns_updater.update_dns_for_instance(local_dns_blob, instance)

          expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(1)
        end
      end

      context 'when sync_dns call times out' do
        it 'does not update agent dns version and cancels the nats request' do
          timeout = Timeout.new(3)
          allow(Timeout).to receive(:new).and_return(timeout)
          expect(timeout).to receive(:timed_out?).and_return(true)

          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance.agent_id) do
            expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
              expect(blobstore_id).to eq('blob-id')
              expect(sha1).to eq(blob_sha1)
              expect(version).to eq(2)
            end.and_return('nats-id')
            agent_client
          end

          expect(agent_client).to receive(:cancel_sync_dns).with('nats-id')

          dns_updater.update_dns_for_instance(local_dns_blob, instance)

          expect(Models::AgentDnsVersion.count).to eq(0)
        end
      end
    end
  end
end
