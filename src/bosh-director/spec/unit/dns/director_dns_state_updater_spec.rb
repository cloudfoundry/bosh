require 'spec_helper'

module Bosh::Director
  describe DirectorDnsStateUpdater do
    subject { described_class.new(dns_encoder) }
    let(:instance) { Models::Instance.make }
    let(:dns_record_info) { ['asdf-asdf-asdf-asdf', 'my-instance-group', 'az1', 'my-network', 'my-deployment', '1.2.3.4'] }
    let(:powerdns_manager) { instance_double(PowerDnsManager) }
    let(:localdns_manager) { instance_double(LocalDnsManager) }
    let(:dns_encoder) { DnsEncoder.new }

    before do
      allow(PowerDnsManagerProvider).to receive(:create).and_return(powerdns_manager)
      allow(LocalDnsManager).to receive(:create).with(
        Config.root_domain,
        Config.logger,
        dns_encoder
      ).and_return(localdns_manager)
    end

    describe '#update_dns_for_instance' do
      it 'calls out to dns manager to update records for instance and flush cache' do
        expect(powerdns_manager).to receive(:update_dns_record_for_instance).with(instance, dns_record_info).ordered
        expect(localdns_manager).to receive(:update_dns_record_for_instance).with(instance)
        expect(powerdns_manager).to receive(:flush_dns_cache).ordered

        subject.update_dns_for_instance(instance, dns_record_info)
      end
    end
  end
end
