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
    let(:dns_updater) { instance_double(DnsUpdater, update_dns_for_instance: nil) }

    before do
      allow(logger).to receive(:info)
      allow(DnsUpdater).to receive(:new).and_return(dns_updater)
    end

    shared_examples_for 'generic converger' do
      it 'no-ops when there are no local dns blobs' do
        Models::LocalDnsBlob.all.each { |local_blob| local_blob.delete }
        is = Models::Instance.make
        Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid', instance_id: is.id)
        expect(dns_updater).to_not receive(:update_dns_for_instance)

        expect { dns_version_converger.update_instances_based_on_strategy }.to_not raise_error
      end

      it 'reaps agent dns version records for agents that no longer exist' do
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        dns_version_converger.update_instances_based_on_strategy
        expect(Models::AgentDnsVersion.count).to eq(0)
      end

      it 'only acts upon instances with an active vm' do
        no_vm_instance = Models::Instance.make
        inactive_vm_instance = Models::Instance.make
        active_vm_instance = Models::Instance.make
        Models::Vm.make(agent_id: 'abc', instance_id: inactive_vm_instance.id)
        Models::Vm.make(agent_id: 'abc-123', instance_id: active_vm_instance.id, active: true)
        expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id)
        expect(dns_updater).to_not receive(:update_dns_for_instance).with(local_dns_blob, no_vm_instance)
        expect(dns_updater).to_not receive(:update_dns_for_instance).with(local_dns_blob, inactive_vm_instance)
        expect(dns_updater).to receive(:update_dns_for_instance).with(local_dns_blob, active_vm_instance)

        dns_version_converger.update_instances_based_on_strategy
      end

      it 'logs progress to the provided logger' do
        instance = Models::Instance.make
        vm = Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid', instance_id: instance.id)
        instance.active_vm = vm
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 1)
        expect(logger).to receive(:info).with('Detected 1 instances with outdated dns versions. Current dns version is 2')
        expect(logger).to receive(:info).with("Updating instance '#{instance}' with agent id 'abc' to dns version '2'")
        expect(logger).to receive(:info).with(/Finished updating instances with latest dns versions. Elapsed time:/)

        dns_version_converger.update_instances_based_on_strategy
      end
    end

    context 'when using the only stale instances selector strategy' do
      it_behaves_like 'generic converger'

      it 'should not update instances that already have current dns records' do
        instance = Models::Instance.make
        Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid', instance_id: instance.id, active: true)
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
        expect(dns_updater).to_not receive(:update_dns_for_instance)

        dns_version_converger.update_instances_based_on_strategy
      end
    end

    context 'when using the all instances with vms selector strategy' do
      it_behaves_like 'generic converger'

      it 'updates all instances, even if they are up to date' do
        dns_version_converger_with_selector = DnsVersionConverger.new(logger, 32, DnsVersionConverger::ALL_INSTANCES_WITH_VMS_SELECTOR)
        instance = Models::Instance.make
        Models::Vm.make(agent_id: 'abc', credentials_json: credentials_json, cid: 'vm-cid', instance_id: instance.id, active: true)
        Models::AgentDnsVersion.create(agent_id: 'abc', dns_version: 2)
        expect(dns_updater).to receive(:update_dns_for_instance).with(local_dns_blob, instance)

        dns_version_converger_with_selector.update_instances_based_on_strategy
      end
    end
  end
end

