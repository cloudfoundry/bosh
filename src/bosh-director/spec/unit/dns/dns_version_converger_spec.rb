require 'spec_helper'

module Bosh::Director
  describe DnsVersionConverger do
    subject(:dns_version_converger) { DnsVersionConverger.new(logger, 32) }
    let(:agent_client) { double(AgentClient) }
    let(:credentials) { {'creds' => 'hash'} }
    let(:blob_sha1) { Digest::SHA1.hexdigest('dns-records') }
    let!(:local_dns_blob) do
      Models::LocalDnsBlob.make(
        blobstore_id: 'blob-id',
        sha1: blob_sha1,
        id: 2,
        created_at: Time.new)
    end

    it 'no-ops when there are no local dns blobs' do
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id)

      Models::LocalDnsBlob.all.each { |local_blob| local_blob.delete }
      Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: 'vm-cid')
      expect { dns_version_converger.update_instances_with_stale_dns_records }.to_not raise_error
    end

    it 'reaps agent dns version records for agents that no longer exist' do
      Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
      dns_version_converger.update_instances_with_stale_dns_records
      expect(Models::AgentDnsVersion.count).to eq(0)
    end

    it 'only acts upon instances with a vm' do
      Models::Instance.make(agent_id: 'no-agent-dns-record', credentials: credentials, vm_cid: nil)
      Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: nil)
      Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
      expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id)

      dns_version_converger.update_instances_with_stale_dns_records

      expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(1)
    end

    it 'does not update agent dns version and cancels the nats request if there was no response' do
      timeout = Timeout.new(3)
      allow(Timeout).to receive(:new).and_return(timeout)
      expect(timeout).to receive(:timed_out?).and_return(true)

      instance = Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: 'vm-cid')

      expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
        with(instance.credentials, instance.agent_id) do
        expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
          expect(agent_client).to receive(:cancel_sync_dns).with('sync-dns-request-id')
          # block is not called
          'sync-dns-request-id'
        end
        agent_client
      end
      dns_version_converger.update_instances_with_stale_dns_records
      expect(Models::AgentDnsVersion.count).to eq(0)
    end

    it 'updates agents that have stale dns records' do
      instance = Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: 'vm-cid')
      Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
      expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
        with(instance.credentials, instance.agent_id) do
        expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
          expect(blobstore_id).to eq('blob-id')
          expect(sha1).to eq(blob_sha1)
          expect(version).to eq(2)
          blk.call({'value' => 'synced'})
        end
        agent_client
      end

      dns_version_converger.update_instances_with_stale_dns_records

      expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(2)
    end

    it 'updates agents that have no agent dns record' do
      Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: 'vm-cid')
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

      dns_version_converger.update_instances_with_stale_dns_records

      expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(2)
    end

    it 'does not update agent dns version if the response was not successful' do
      Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: 'vm-cid')
      Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
      expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
        with(credentials, 'abc') do
        expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
          expect(blobstore_id).to eq('blob-id')
          expect(sha1).to eq(blob_sha1)
          expect(version).to eq(2)
          blk.call({'value' => 'nope'})
        end
        agent_client
      end

      dns_version_converger.update_instances_with_stale_dns_records

      expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(1)
    end

    it 'should not update instances that already have current dns records' do
      Models::Instance.make(agent_id: 'abc', credentials: credentials, vm_cid: 'vm-cid')
      Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
      expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id)

      dns_version_converger.update_instances_with_stale_dns_records
    end
  end
end

