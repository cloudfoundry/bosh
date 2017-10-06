require 'spec_helper'

module Bosh::Director
  describe DnsRecords do
    let(:include_index_records) { false }
    let(:version) { 2 }
    let(:az_hash) {{ 'az1' => '3', 'az2' => '7', 'az3' => '11' }}
    let(:groups_hash) {{
      {instance_group: 'group-name1', deployment: 'dep-name1'} => '11',
      {instance_group: 'group-name2', deployment: 'dep-name2'} => '12',
      {instance_group: 'group_name3', deployment: 'dep_name3'} => '13',
    }}
    let(:dns_encoder) { DnsEncoder.new(groups_hash, az_hash) }
    let(:dns_records) { DnsRecords.new(version, include_index_records, dns_encoder) }

    describe '#to_json' do
      context 'with records' do
        before do
          dns_records.add_record('uuid1', 1, 'group-name1', 'az1', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1')
          dns_records.add_record('uuid2', 2, 'group-name2', 'az2', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1')
          dns_records.add_record('uuid3', 3, 'group-name2', nil, 'net-name2', 'dep-name2', 'ip-addr3', 'bosh1.tld', 'fake-agent-uuid1')
        end

        it 'returns json' do
          expected_records = {
             'records' => [
                 ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                 ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
                 ['ip-addr3', 'uuid3.group-name2.net-name2.dep-name2.bosh1.tld']],
             'version' => 2,
             'record_keys' =>
                 ['id', 'instance_group', 'group_ids', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id', 'instance_index'],
             'record_infos' => [
                 ['uuid1', 'group-name1', ['11'], 'az1', '3', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1', 1],
                 ['uuid2', 'group-name2', ['12'], 'az2', '7', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1', 2],
                 ['uuid3', 'group-name2', ['12'], nil, nil, 'net-name2', 'dep-name2', 'ip-addr3', 'bosh1.tld', 'fake-agent-uuid1', 3]],
          }
          expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
        end

        it 'returns the shasum' do
          expect(dns_records.shasum).to eq('bb76182dcd83143a3627c35622626b3575e62481')
        end

        context 'when index records are enabled' do
          let(:include_index_records) { true }

          it 'returns json' do
            expected_records = {
                'records' => [
                    ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                    ['ip-addr1', '1.group-name1.net-name1.dep-name1.bosh1.tld'],
                    ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
                    ['ip-addr2', '2.group-name2.net-name2.dep-name2.bosh1.tld'],
                    ['ip-addr3', 'uuid3.group-name2.net-name2.dep-name2.bosh1.tld'],
                    ['ip-addr3', '3.group-name2.net-name2.dep-name2.bosh1.tld']],
                'version' => 2,
                'record_keys' =>
                    ['id', 'instance_group', 'group_ids', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id', 'instance_index'],
                'record_infos' => [
                    ['uuid1', 'group-name1', ['11'], 'az1', '3', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1', 1],
                    ['uuid2', 'group-name2', ['12'], 'az2', '7', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1', 2],
                    ['uuid3', 'group-name2', ['12'], nil, nil, 'net-name2', 'dep-name2', 'ip-addr3', 'bosh1.tld', 'fake-agent-uuid1', 3]],
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
        end

        context 'canonicalization' do
          before do
            dns_records.add_record('uuid4', 4, 'group_name3', 'az3', 'net_name3', 'dep_name3', 'ip-addr4', 'bosh3.tld', 'fake-agent-uuid3')
          end

          it 'canonicalizes the network name, deployment name and instance group name' do
            expected_records = {
              'records' => [
                ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
                ['ip-addr3', 'uuid3.group-name2.net-name2.dep-name2.bosh1.tld'],
                ['ip-addr4', 'uuid4.group-name3.net-name3.dep-name3.bosh3.tld']],
              'version' => 2,
              'record_keys' =>
                ['id', 'instance_group', 'group_ids', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id', 'instance_index'],
              'record_infos' => [
                ['uuid1', 'group-name1', ['11'], 'az1', '3', 'net-name1', 'dep-name1', 'ip-addr1', 'bosh1.tld', 'fake-agent-uuid1', 1],
                ['uuid2', 'group-name2', ['12'], 'az2', '7', 'net-name2', 'dep-name2', 'ip-addr2', 'bosh1.tld', 'fake-agent-uuid1', 2],
                ['uuid3', 'group-name2', ['12'], nil, nil, 'net-name2', 'dep-name2', 'ip-addr3', 'bosh1.tld', 'fake-agent-uuid1', 3],
                ['uuid4', 'group-name3', ['13'], 'az3', '11', 'net-name3', 'dep-name3', 'ip-addr4', 'bosh3.tld', 'fake-agent-uuid3', 4]]
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
        end
      end

      context 'when have 0 records' do
        it 'returns empty json' do
          expect(dns_records.to_json).to eq('{"records":[],"version":2,"record_keys":["id","instance_group","group_ids","az","az_id","network","deployment","ip","domain","agent_id","instance_index"],"record_infos":[]}')
          expect(dns_records.to_json).to eq('{"records":[],"version":2,"record_keys":["id","instance_group","group_ids","az","az_id","network","deployment","ip","domain","agent_id","instance_index"],"record_infos":[]}')
        end
      end
    end
  end
end
