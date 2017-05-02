require 'spec_helper'

module Bosh::Director
  describe DirectorDnsStateUpdater do
    let(:instance) { Models::Instance.make }
    let(:dns_record_info) { ['asdf-asdf-asdf-asdf', 'my-instance-group', 'az1', 'my-network', 'my-deployment', '1.2.3.4'] }
    let(:dns_manager) { instance_double(DnsManager) }
    let(:dns_publisher) { instance_double(BlobstoreDnsPublisher) }
    let(:local_dns_repo) { instance_double(LocalDnsRepo) }

    before do
      allow(BlobstoreDnsPublisher).to receive(:new).and_return(dns_publisher)
      allow(DnsManagerProvider).to receive(:create).and_return(dns_manager)
      allow(LocalDnsRepo).to receive(:new).and_return(local_dns_repo).with(Config.logger, Config.root_domain)
    end

    describe '#update_dns_for_instance' do
      it 'calls out to dns manager to update records for instance and flush cache' do
        expect(dns_manager).to receive(:update_dns_record_for_instance).with(instance, dns_record_info).ordered
        expect(local_dns_repo).to receive(:update_for_instance).with(instance)
        expect(dns_manager).to receive(:flush_dns_cache).ordered
        expect(dns_publisher).to receive(:publish_and_broadcast).ordered

        subject.update_dns_for_instance(instance, dns_record_info)
      end
    end

    describe '#publish_dns_records' do
      it 'delegates to dns_manager' do
        expect(dns_publisher).to receive(:publish_and_broadcast)

        subject.publish_dns_records
      end
    end
  end
end
