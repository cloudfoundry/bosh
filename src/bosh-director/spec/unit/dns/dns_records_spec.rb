require 'spec_helper'

module Bosh::Director
  describe DnsRecords do
    let(:version) { 2 }
    let(:dns_records) { DnsRecords.new(version) }

    describe '#to_json' do
      context 'when have records' do
        before do
          dns_records.add_record('index', 'group-name', 'az1', 'net-name1', 'dep-name', 'ip-addr1', 'fqdn1')
          dns_records.add_record('uuid', 'group-name', 'az1', 'net-name2', 'dep-name', 'ip-addr2', 'fqdn2')
        end

        it 'returns json' do
          expect(dns_records.to_json).to eq('{"records":[["ip-addr1","fqdn1"],["ip-addr2","fqdn2"]],"version":2,"record_keys":["id","instance_group","az","network","deployment","ip"],"record_infos":[["index","group-name","az1","net-name1","dep-name","ip-addr1"],["uuid","group-name","az1","net-name2","dep-name","ip-addr2"]]}')
        end
      end

      context 'when have 0 records' do
        it 'returns empty json' do
          expect(dns_records.to_json).to eq('{"records":[],"version":2,"record_keys":["id","instance_group","az","network","deployment","ip"],"record_infos":[]}')
        end
      end
    end
  end
end
