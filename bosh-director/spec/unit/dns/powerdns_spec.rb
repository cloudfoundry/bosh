require 'spec_helper'

module Bosh::Director
  describe PowerDns do
    subject(:power_dns) { PowerDns.new('bosh', logger) }
    describe '#create_or_update' do
      context 'when dns record does not exist' do
        it 'creates domain and ptr domain' do
          expect {
            power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          }.to change{ Models::Dns::Domain.count }.from(0).to(2)

          expect(Models::Dns::Domain.all.map(&:name)).to contain_exactly('bosh', '3.2.1.in-addr.arpa')
        end

        it 'creates new A record' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          record = Models::Dns::Record.find(type: 'A')
          expect(record.name).to eq('1.foobar.network.dep.bosh')
          expect(record.content).to eq('1.2.3.4')
        end

        it 'creates new ptr records' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
          ns_record = Models::Dns::Record.find(type: 'NS')
          expect(ns_record.name).to eq('3.2.1.in-addr.arpa')
          expect(ns_record.content).to eq('ns.bosh')

          soa_record = Models::Dns::Record.find(type: 'SOA')
          expect(soa_record.name).to eq('3.2.1.in-addr.arpa')
          expect(soa_record.content).to eq('localhost hostmaster@localhost 0 10800 604800 30')

          ptr_record = Models::Dns::Record.find(type: 'PTR')
          expect(ptr_record.name).to eq('4.3.2.1.in-addr.arpa')
          expect(ptr_record.content).to eq('1.foobar.network.dep.bosh')
        end
      end

      context 'when dns record exists' do
        before do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '1.2.3.4')
        end

        it 'updates ip address on A record' do
          expect {
            power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '5.6.7.8')
          }.to_not change { Models::Dns::Domain.count }

          record = Models::Dns::Record.find(type: 'A')
          expect(record.name).to eq('1.foobar.network.dep.bosh')
          expect(record.content).to eq('5.6.7.8')
        end

        it 'updates ptr records' do
          power_dns.create_or_update_dns_records('1.foobar.network.dep.bosh', '5.6.7.8')
          ns_record = Models::Dns::Record.find(type: 'NS')
          expect(ns_record.name).to eq('7.6.5.in-addr.arpa')
          expect(ns_record.content).to eq('ns.bosh')

          soa_record = Models::Dns::Record.find(type: 'SOA')
          expect(soa_record.name).to eq('7.6.5.in-addr.arpa')
          expect(soa_record.content).to eq('localhost hostmaster@localhost 0 10800 604800 30')

          ptr_record = Models::Dns::Record.find(type: 'PTR')
          expect(ptr_record.name).to eq('8.7.6.5.in-addr.arpa')
          expect(ptr_record.content).to eq('1.foobar.network.dep.bosh')
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

      it 'deletes dns record' do
        power_dns.delete('1.foobar.%.dep.bosh')
        expect(Models::Dns::Record.filter(type: 'A').map(&:name)).to eq(['uuid1uuid.foobar.network-a.dep.bosh'])
      end

      it 'deletes ptr records associated with the pattern' do
        power_dns.delete('1.foobar.%.dep.bosh')
        expect(Models::Dns::Record.filter(type: 'PTR').map(&:content)).to eq(['uuid1uuid.foobar.network-a.dep.bosh'])
      end

      it 'deletes the NS and SOA records when there are no more A/PTR records in the domain' do
        power_dns.delete('%.foobar.%.dep.bosh')
        expect(Models::Dns::Record.filter(type: 'NS').all.size).to eq(0)
        expect(Models::Dns::Record.filter(type: 'SOA').all.size).to eq(0)
      end

      it 'deletes empty reverse domain' do
        expect {
          power_dns.delete('%.foobar.%.dep.bosh')
        }.to change { Models::Dns::Domain.all.size }.from(2).to(1)
      end
    end
  end
end
