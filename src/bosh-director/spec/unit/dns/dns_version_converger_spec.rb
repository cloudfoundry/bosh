require 'spec_helper'

module Bosh::Director
  describe DnsVersionConverger do
    subject(:dns_version_converger) { DnsVersionConverger.new(logger, 32) }
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
    shared_examples_for 'generic converger' do
      it 'no-ops when there are no local dns blobs' do
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id)

        Models::LocalDnsBlob.all.each { |local_blob| local_blob.delete }
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        is = Models::Instance.make
        expect { dns_version_converger.update_instances_based_on_strategy }.to_not raise_error
      end

      it 'reaps agent dns version records for agents that no longer exist' do
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        dns_version_converger.update_instances_based_on_strategy
        expect(Models::AgentDnsVersion.count).to eq(0)
      end

      it 'only acts upon instances with a vm' do
        Models::Instance.make
        Models::Instance.make
        Models::Vm.make(agent_id: 'abc')
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id)

        dns_version_converger.update_instances_based_on_strategy

        expect(Models::AgentDnsVersion.all.length).to eq(1)
        expect(Models::AgentDnsVersion.all.first.dns_version).to eq(1)
      end

      it 'does not update agent dns version and cancels the nats request if there was no response' do
        timeout = Timeout.new(3)
        allow(Timeout).to receive(:new).and_return(timeout)
        expect(timeout).to receive(:timed_out?).and_return(true)

        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)

        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
          with(instance.credentials, instance.agent_id) do
          expect(agent_client).to receive(:sync_dns) do |blobstore_id, sha1, version, &blk|
            expect(agent_client).to receive(:cancel_sync_dns).with('sync-dns-request-id')
            # block is not called
            'sync-dns-request-id'
          end
          agent_client
        end
        dns_version_converger.update_instances_based_on_strategy
        expect(Models::AgentDnsVersion.count).to eq(0)
      end

      it 'logs to the provided logger' do
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id) do
          expect(agent_client).to receive(:sync_dns) do | _, _, _, &blk|
            blk.call({'value' => 'synced'})
          end
          agent_client
        end
        expect(logger).to receive(:info).with('Detected 1 instances with outdated dns versions. Current dns version is 2')
        expect(logger).to receive(:info).with("Updating instance '#{instance}' with agent id 'abc' to dns version '2'")
        expect(logger).to receive(:info).with("Successfully updated instance '#{instance}' with agent id 'abc' to dns version 2. agent sync_dns response: '{\"value\"=>\"synced\"}'")
        expect(logger).to receive(:info).with(/Finished updating instances with latest dns versions. Elapsed time:/)

        dns_version_converger.update_instances_based_on_strategy
      end

      it 'logs that there were problems updating the dns record when the response is not successful' do
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id) do
          expect(agent_client).to receive(:sync_dns) do | _, _, _, &blk|
            blk.call({'value' => 'nope'})
          end
          agent_client
        end
        expect(logger).to receive(:info).with('Detected 1 instances with outdated dns versions. Current dns version is 2')
        expect(logger).to receive(:info).with("Updating instance '#{instance}' with agent id 'abc' to dns version '2'")
        expect(logger).to receive(:info).with("Failed to update instance '#{instance}' with agent id 'abc' to dns version 2. agent sync_dns response: '{\"value\"=>\"nope\"}'")
        expect(logger).to receive(:info).with(/Finished updating instances with latest dns versions. Elapsed time:/)
        dns_version_converger.update_instances_based_on_strategy
      end

      it 'updates agents that have no agent dns record' do
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)
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

        dns_version_converger.update_instances_based_on_strategy

        expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(2)
      end

      it 'does not update agent dns version if the response was not successful' do
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        is = Models::Instance.make
        is.add_vm vm
        is.update(active_vm: vm)
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

        dns_version_converger.update_instances_based_on_strategy

        expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(1)
      end

      it 'updates agents that have stale dns records' do
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)
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

        dns_version_converger.update_instances_based_on_strategy

        expect(Models::AgentDnsVersion.first(agent_id: 'abc').dns_version).to eq(2)
      end
    end

    context 'when using the only stale instances selector strategy' do
      it_behaves_like 'generic converger'

      it 'should not update instances that already have current dns records' do
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
        expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id)

        dns_version_converger.update_instances_based_on_strategy
      end
    end

    context 'when using the all instances with vms selector strategy' do
      it_behaves_like 'generic converger'

      it 'updates all instances, even if they are up to date' do
        dns_version_converger_with_selector = DnsVersionConverger.new(logger, 32, DnsVersionConverger::ALL_INSTANCES_WITH_VMS_SELECTOR)
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid')
        instance = Models::Instance.make
        instance.add_vm vm
        instance.update(active_vm: vm)
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
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

        dns_version_converger_with_selector.update_instances_based_on_strategy
      end
    end
  end
end

