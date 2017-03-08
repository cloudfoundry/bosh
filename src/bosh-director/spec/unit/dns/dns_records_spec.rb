require 'spec_helper'

module Bosh::Director
  describe DnsRecords do
    let(:records) { [['fake-ip1', 'fake-name1'], ['fake-ip2', 'fake-name2']]}
    let(:version) { 2 }
    let(:dns_records) { DnsRecords.new(records, version) }

    describe '#to_json' do
      context 'when have records' do
        it 'returns json' do
          expect(dns_records.to_json).to eq('{"records":[["fake-ip1","fake-name1"],["fake-ip2","fake-name2"]],"version":2}')
        end
      end

      context 'when have 0 records' do
        it 'returns empty json' do
          expect(DnsRecords.new.to_json).to eq('{"records":[],"version":0}')
        end
      end
    end
  end
end
