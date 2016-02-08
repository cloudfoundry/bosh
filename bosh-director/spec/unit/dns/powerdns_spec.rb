require 'spec_helper'

module Bosh::Director
  describe PowerDns do
    subject(:power_dns) { PowerDns.new('bosh', logger) }
    describe '#create_or_update' do
      context 'when dns record does not exist' do

        it 'creates new A record' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          record = Models::Dns::Record.find(name: '1.foobar.network.dep.bosh', content: '1.2.3.4', type: 'A')
          expect(record).to exist
        end

        it 'creates a new PTR record' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          ptr_record = Models::Dns::Record.find(
            name: '4.3.2.1.in-addr.arpa',
            content: '1.foobar.network.dep.bosh',
            type: 'PTR'
          )
          expect(ptr_record).to exist
        end

        it 'creates a domain' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          domain = Models::Dns::Domain.find(name: 'bosh', type: 'NATIVE')
          expect(domain).to exist
        end

        it 'creates a PTR domain' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          ptr_domain = Models::Dns::Domain.find(name: '3.2.1.in-addr.arpa', type: 'NATIVE')
          expect(ptr_domain).to exist
        end

        it 'creates a new NS record in the new domain' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          ns_record = Models::Dns::Record.find(name: '3.2.1.in-addr.arpa', content: 'ns.bosh', type: 'NS')
          expect(ns_record).to exist
        end

        it 'creates a new SOA record in the new domain' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          soa_record = Models::Dns::Record.find(
            name: '3.2.1.in-addr.arpa',
            content: 'localhost hostmaster@localhost 0 10800 604800 30',
            type: 'SOA'
          )
          expect(soa_record).to exist
        end
      end

      context 'when a dns record exists' do
        before do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
        end

        it 'updates the ip address on A record' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '5.6.7.8')
          records = Models::Dns::Record.where(name: '1.foobar.network.dep.bosh', type: 'A')
          expect(records.map(&:content)).to eq(['5.6.7.8'])
        end

        it 'updates PTR records' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '5.6.7.8')
          ptr_records = Models::Dns::Record.where(name: '8.7.6.5.in-addr.arpa', type: 'PTR')
          expect(ptr_records.map(&:content)).to eq(['1.foobar.network.dep.bosh'])
        end

        it 'creates a new NS record in the new domain' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '5.6.7.8')
          ns_record = Models::Dns::Record.find(name: '7.6.5.in-addr.arpa', content: 'ns.bosh', type: 'NS')
          expect(ns_record).to exist
        end

        it 'creates a new SOA record in the new domain' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '5.6.7.8')
          soa_record = Models::Dns::Record.find(
            name: '7.6.5.in-addr.arpa',
            content: 'localhost hostmaster@localhost 0 10800 604800 30',
            type: 'SOA'
          )
          expect(soa_record).to exist
        end
      end
    end

    describe '#delete' do
      let(:ip) {'1.2.3.4'}

      before do
        power_dns.create_or_update_dns_records('1.foobar.network-a.dep.bosh', ip)
        power_dns.create_or_update_dns_records('uuid1uuid.foobar.network-a.dep.bosh', ip)
        power_dns.create_or_update_dns_records('1.foobar.network-b.dep.bosh', ip)
      end

      it 'deletes A records' do
        power_dns.delete('1.foobar.%.dep.bosh')
        expect(Models::Dns::Record.filter(type: 'A').map(&:name)).to eq(['uuid1uuid.foobar.network-a.dep.bosh'])
      end

      it 'deletes PTR records associated with the pattern' do
        power_dns.delete('1.foobar.%.dep.bosh')
        expect(Models::Dns::Record.filter(type: 'PTR').map(&:content)).to eq(['uuid1uuid.foobar.network-a.dep.bosh'])
      end
    end
  end
end
