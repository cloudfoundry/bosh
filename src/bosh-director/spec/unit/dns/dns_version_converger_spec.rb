require 'spec_helper'

module Bosh::Director
  describe DnsVersionConverger do
    subject(:dns_version_converger) { DnsVersionConverger.new(agent_broadcaster, logger, 32) }
    let(:agent_client) { double(AgentClient) }
    let(:credentials) do
      { 'creds' => 'hash' }
    end
    let(:credentials_json) { JSON.generate(credentials) }
    let(:blob_sha1) { ::Digest::SHA1.hexdigest('dns-records') }
    let(:logger) { double(Logger) }
    let(:blob) do
      FactoryBot.create(:models_blob,
                        blobstore_id: 'blob-id',
                        sha1: blob_sha1,
      )
    end
    let!(:local_dns_blob) do
      FactoryBot.create(:models_local_dns_blob,
                        blob: blob,
                        version: 2,
                        created_at: Time.new)
    end
    let(:agent_broadcaster) { AgentBroadcaster.new }

    before do
      allow(logger).to receive(:info)
    end

    shared_examples_for 'generic converger' do
      it 'no-ops when there are no local dns blobs' do
        Models::LocalDnsBlob.all.each { |local_blob| local_blob.delete }
        FactoryBot.create(:models_instance).tap do |i|
          FactoryBot.create(:models_vm, agent_id: 'abc', cid: 'vm-cid', instance_id: i.id)
        end
        expect(agent_broadcaster).to_not receive(:sync_dns)

        expect { dns_version_converger.update_instances_based_on_strategy }.to_not raise_error
      end

      it 'reaps agent dns version records for agents that no longer exist' do
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        expect(agent_broadcaster).to_not receive(:sync_dns)
        dns_version_converger.update_instances_based_on_strategy
        expect(Models::AgentDnsVersion.count).to eq(0)
      end

      it 'only acts upon instances with an active vm' do
        FactoryBot.create(:models_instance).tap do |i|
          FactoryBot.create(:models_vm, agent_id: 'abc', instance_id: i.id)
        end
        active_vm_instance =
          FactoryBot.create(:models_instance).tap do |i|
            FactoryBot.create(:models_vm, agent_id: 'abc-123', instance_id: i.id, active: true)
          end
        expect(AgentClient).to_not receive(:with_agent_id)
        expect(agent_broadcaster).to receive(:sync_dns).with([active_vm_instance], 'blob-id', blob_sha1, 2)

        dns_version_converger.update_instances_based_on_strategy
      end

      it 'logs progress to the provided logger' do
        FactoryBot.create(:models_instance).tap do |i|
          i.active_vm = FactoryBot.create(:models_vm, agent_id: 'abc', cid: 'vm-cid', instance_id: i.id)
        end

        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        expect(logger).to receive(:info).with('Detected 1 instances with outdated dns versions. Current dns version is 2')
        expect(logger).to receive(:info).with(/Finished updating instances with latest dns versions. Elapsed time:/)
        expect(agent_broadcaster).to receive(:sync_dns)

        dns_version_converger.update_instances_based_on_strategy
      end
    end

    context 'when using the only stale instances selector strategy' do
      it_behaves_like 'generic converger'

      it 'should not update instances that already have current dns records' do
        FactoryBot.create(:models_instance).tap do |i|
          FactoryBot.create(:models_vm, agent_id: 'abc', cid: 'vm-cid', instance_id: i.id, active: true)
        end

        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
        expect(agent_broadcaster).to_not receive(:sync_dns)

        dns_version_converger.update_instances_based_on_strategy
      end

      it 'does not update compilation vms' do
        FactoryBot.create(:models_instance, compilation: true).tap do |i|
          FactoryBot.create(:models_vm, agent_id: 'abc', cid: 'vm-cid', instance_id: i.id, active: true)
        end

        expect(agent_broadcaster).to_not receive(:sync_dns)

        dns_version_converger.update_instances_based_on_strategy
      end
    end

    context 'when using the all instances with vms selector strategy' do
      it_behaves_like 'generic converger'

      it 'updates all non-compilation instances, even if they are up to date' do
        dns_version_converger_with_selector =
          DnsVersionConverger.new(agent_broadcaster, logger, 32, DnsVersionConverger::ALL_INSTANCES_WITH_VMS_SELECTOR)
        instance =
          FactoryBot.create(:models_instance).tap do |i|
            FactoryBot.create(:models_vm, agent_id: 'abc', cid: 'vm-cid', instance_id: i.id, active: true)
          end

        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
        expect(agent_broadcaster).to receive(:sync_dns).with([instance], 'blob-id', blob_sha1, 2)

        dns_version_converger_with_selector.update_instances_based_on_strategy
      end

      it 'does not update compilation vms' do
        dns_version_converger_with_selector =
          DnsVersionConverger.new(agent_broadcaster, logger, 32, DnsVersionConverger::ALL_INSTANCES_WITH_VMS_SELECTOR)

        FactoryBot.create(:models_instance, compilation: true).tap do |i|
          FactoryBot.create(:models_vm, agent_id: 'abc', cid: 'vm-cid', instance_id: i.id, active: true)
        end
        expect(agent_broadcaster).to_not receive(:sync_dns)

        dns_version_converger_with_selector.update_instances_based_on_strategy
      end
    end
  end
end
