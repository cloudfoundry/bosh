require 'spec_helper'

module Bosh::Director
  describe DnsRecords do
    let(:include_index_records) { false }
    let(:version) { 2 }
    let(:dns_records) { DnsRecords.new(version, include_index_records) }

    describe '#to_json' do
      context 'with records' do
        before do
          dns_records.add_record('uuid1', 'index1', 'group-name1', 'az1', 'net-name1', 'dep-name1', 'ip-addr1')
          dns_records.add_record('uuid2', 'index2', 'group-name2', 'az2', 'net-name2', 'dep-name2', 'ip-addr2')
        end

        it 'returns json' do
          expected_records = {
             'records' => [
                 ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh'],
                 ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh']],
             'version' => 2,
             'record_keys' =>
                 ['id', 'instance_group', 'az', 'network', 'deployment', 'ip'],
             'record_infos' => [
                 ['uuid1', 'group-name1', 'az1', 'net-name1', 'dep-name1', 'ip-addr1'],
                 ['uuid2', 'group-name2', 'az2', 'net-name2', 'dep-name2', 'ip-addr2']]
          }
          expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
        end

        it 'returns the shasum' do
          expect(dns_records.shasum).to eq('64d434471082add36366cd1bd7742c08de2811dd')
        end

        context 'when index records are enabled' do
          let(:include_index_records) { true }

          it 'returns json' do
            expected_records = {
                'records' => [
                    ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh'],
                    ['ip-addr1', 'index1.group-name1.net-name1.dep-name1.bosh'],
                    ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh'],
                    ['ip-addr2', 'index2.group-name2.net-name2.dep-name2.bosh']],
                'version' => 2,
                'record_keys' =>
                    ['id', 'instance_group', 'az', 'network', 'deployment', 'ip'],
                'record_infos' => [
                    ['uuid1', 'group-name1', 'az1', 'net-name1', 'dep-name1', 'ip-addr1'],
                    ['uuid2', 'group-name2', 'az2', 'net-name2', 'dep-name2', 'ip-addr2']]
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
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
