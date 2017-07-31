require 'spec_helper'

module Bosh::Director
  describe DnsRecords do
    let(:include_index_records) { false }
    let(:version) { 2 }
    let(:dns_records) do
      az_hash = {
        'az1' => 3,
        'az2' => 7,
        'az3' => 11
      }

      DnsRecords.new(version, include_index_records, az_hash, logger)
    end

    let(:logger) { double }

    describe '#to_json' do
      context 'with records' do
        before do
          dns_records.add_record('uuid1', 'index1', 'group-name1', 'az1', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1')
          dns_records.add_record('uuid2', 'index2', 'group-name2', 'az2', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1')
        end

        it 'returns json' do
          expected_records = {
             'records' => [
                 ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                 ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld']],
             'version' => 2,
             'record_keys' =>
                 ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id'],
             'record_infos' => [
                 ['uuid1', 'group-name1', 'az1', '3', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1'],
                 ['uuid2', 'group-name2', 'az2', '7', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1']],
          }
          expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
        end

        it 'returns the shasum' do
          expect(dns_records.shasum).to eq('f817c4ea212c65e66c755df452c6a31cb53fb614')
        end

        context 'when a record with unrecognized AZ name is presented' do
          it 'logs a message' do
            expect(logger).to receive(:debug).with /unknown-az/
            dns_records.add_record('uuid2', 'index2', 'group-name2', 'unknown-az', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1')
          end
        end


        context 'when index records are enabled' do
          let(:include_index_records) { true }

          it 'returns json' do
            expected_records = {
                'records' => [
                    ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                    ['ip-addr1', 'index1.group-name1.net-name1.dep-name1.bosh1.tld'],
                    ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
                    ['ip-addr2', 'index2.group-name2.net-name2.dep-name2.bosh1.tld']],
                'version' => 2,
                'record_keys' =>
                    ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id'],
                'record_infos' => [
                    ['uuid1', 'group-name1', 'az1', '3', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1'],
                    ['uuid2', 'group-name2', 'az2', '7', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1']]
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
        end

        context 'canonicalization' do
          before do
            dns_records.add_record('uuid3', 'index3', 'group_name3', 'az3', 'net_name3', 'dep_name3', 'ip-addr3', 'bosh3.tld', 'fake-agent-uuid3')
          end
          
          it 'canonicalizes the network name, deployment name and instance group name' do
            expected_records = {
              'records' => [
                ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
                ['ip-addr3', 'uuid3.group-name3.net-name3.dep-name3.bosh3.tld']],
              'version' => 2,
              'record_keys' =>
                ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id'],
              'record_infos' => [
                ['uuid1', 'group-name1', 'az1', '3', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1'],
                ['uuid2', 'group-name2', 'az2', '7', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1'],
                ['uuid3', 'group-name3', 'az3', '11', 'net-name3', 'dep-name3', 'ip-addr3', 'bosh3.tld', 'fake-agent-uuid3']]
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
        end
      end

      context 'when have 0 records' do
        it 'returns empty json' do
          expect(dns_records.to_json).to eq('{"records":[],"version":2,"record_keys":["id","instance_group","az","az_id","network","deployment","ip","domain","agent_id"],"record_infos":[]}')
        end
      end
    end
  end
end
