require 'spec_helper'

module Bosh::Director
  describe LocalDnsManager do
    subject(:local_dns_manager) do
      LocalDnsManager.new(Config.root_domain, local_dns_records_repo, blobstore_dns_publisher, logger)
    end

    let(:instance_model) { Models::Instance.make }
    let(:local_dns_records_repo) { instance_double(LocalDnsRecordsRepo) }
    let(:blobstore_dns_publisher) { instance_double(BlobstoreDnsPublisher) }

    describe '.create' do
      it 'should create a dns repo and blobstore_dns_publisher and make a new dns manager' do
        expect(LocalDnsRecordsRepo).to receive(:new).with(logger, Config.root_domain)
        expect(BlobstoreDnsPublisher).to receive(:new).with(anything, Config.root_domain, anything, logger)

        expect(LocalDnsManager.create(Config.root_domain, logger)).to be_a(LocalDnsManager)
      end
    end

    describe '#update_dns_for_instance' do
      it 'should delegate to local_dns_records_repo and publish' do
        expect(local_dns_records_repo).to receive(:update_for_instance).with(instance_model)
        expect(blobstore_dns_publisher).to receive(:publish_and_broadcast)

        local_dns_manager.update_dns_record_for_instance(instance_model)
      end
    end

    describe '#delete_dns_record_for_instance' do
      it 'should delegate to local_dns_records_repo and publish' do
        expect(local_dns_records_repo).to receive(:delete_for_instance).with(instance_model)
        expect(blobstore_dns_publisher).to receive(:publish_and_broadcast)

        local_dns_manager.delete_dns_for_instance(instance_model)
      end
    end
  end
end
