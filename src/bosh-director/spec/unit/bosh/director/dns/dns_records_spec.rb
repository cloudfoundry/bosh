require 'spec_helper'

module Bosh::Director
  describe DnsRecords do
    let(:include_index_records) { false }
    let(:version) { 2 }
    let(:az_hash) do
      { 'az1' => '3', 'az2' => '7', 'az3' => '11' }
    end
    let(:network_name_hash) do
      { 'net-name1' => '1', 'net-name2' => '2', 'net-name3' => '3' }
    end
    let(:groups_hash) do
      {
        {
          group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
          group_name: 'group-name1',
          deployment: 'dep-name1',
        } => '11',
        {
          group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
          group_name: 'group-name2',
          deployment: 'dep-name2',
        } => '12',
        {
          group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
          group_name: 'group_name3',
          deployment: 'dep_name3',
        } => '13',
        {
          group_type: Models::LocalDnsEncodedGroup::Types::LINK,
          group_name: 'link-name-1-type-1',
          deployment: 'dep-name2',
        } => '14',
        {
          group_type: Models::LocalDnsEncodedGroup::Types::LINK,
          group_name: 'link-name-2-type-2',
          deployment: 'dep-name2',
        } => '15',
      }
    end
    let(:dns_encoder) { DnsEncoder.new(groups_hash, az_hash, network_name_hash) }
    let(:dns_records) { DnsRecords.new(version, include_index_records, dns_encoder) }

    before(:each) do
      network_name_hash.each do |name, id|
        FactoryBot.create(:models_local_dns_encoded_network, id: id, name: name)
      end
    end

    describe '#to_json' do
      context 'with records' do
        before do
          dns_records.add_record(
            instance_id:         'uuid1',
            num_id:              0,
            index:               1,
            instance_group_name: 'group-name1',
            az_name:             'az1',
            network_name:        'net-name1',
            deployment_name:     'dep-name1',
            ip:                  'ip-addr1',
            domain:              'bosh1.tld',
            agent_id:            'fake-agent-uuid1',
          )
          dns_records.add_record(
            instance_id:         'uuid2',
            num_id:              1,
            index:               2,
            instance_group_name: 'group-name2',
            az_name:             'az2',
            network_name:        'net-name2',
            deployment_name:     'dep-name2',
            ip:                  'ip-addr2',
            domain:              'bosh1.tld',
            agent_id:            'fake-agent-uuid1',
            links:                [{ name: 'link-name-1-type-1' }],
          )
          dns_records.add_record(
            instance_id:         'uuid3',
            num_id:              2,
            index:               3,
            instance_group_name: 'group-name2',
            az_name:             nil,
            network_name:        'net-name2',
            deployment_name:     'dep-name2',
            ip:                  'ip-addr3',
            domain:              'bosh1.tld',
            agent_id:            'fake-agent-uuid1',
            links:               [{ name: 'link-name-2-type-2' }],
          )
        end

        it 'returns json' do
          expected_records = {
            'records' => [
              ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
              ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
              ['ip-addr3', 'uuid3.group-name2.net-name2.dep-name2.bosh1.tld'],
            ],
            'version' => 2,
            'aliases' => {},
            'record_keys' => %w[
              id num_id instance_group group_ids az az_id network network_id
              deployment ip domain agent_id instance_index
            ],
            'record_infos' => [
              [
                'uuid1',
                '0',
                'group-name1',
                %w[11],
                'az1',
                '3',
                'net-name1',
                '1',
                'dep-name1',
                'ip-addr1',
                'bosh1.tld',
                'fake-agent-uuid1',
                1,
              ],
              [
                'uuid2',
                '1',
                'group-name2',
                %w[12 14],
                'az2',
                '7',
                'net-name2',
                '2',
                'dep-name2',
                'ip-addr2',
                'bosh1.tld',
                'fake-agent-uuid1',
                2,
              ],
              [
                'uuid3',
                '2',
                'group-name2',
                %w[12 15],
                nil,
                nil,
                'net-name2',
                '2',
                'dep-name2',
                'ip-addr3',
                'bosh1.tld',
                'fake-agent-uuid1',
                3,
              ],
            ],
          }
          expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
        end

        it 'returns the shasum' do
          expect(dns_records.shasum).to eq('sha256:2e4cee79506738d9aa8ee467a1ce3ed0c4342f04060ecfc690a92a9ac743123e')
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
                ['ip-addr3', '3.group-name2.net-name2.dep-name2.bosh1.tld'],
              ],
              'version' => 2,
              'record_keys' => %w[
                id num_id instance_group group_ids az az_id network network_id
                deployment ip domain agent_id instance_index
              ],
              'aliases' => {},
              'record_infos' => [
                [
                  'uuid1',
                  '0',
                  'group-name1',
                  %w[11],
                  'az1',
                  '3',
                  'net-name1',
                  '1',
                  'dep-name1',
                  'ip-addr1',
                  'bosh1.tld',
                  'fake-agent-uuid1',
                  1,
                ],
                [
                  'uuid2',
                  '1',
                  'group-name2',
                  %w[12 14],
                  'az2',
                  '7',
                  'net-name2',
                  '2',
                  'dep-name2',
                  'ip-addr2',
                  'bosh1.tld',
                  'fake-agent-uuid1',
                  2,
                ],
                [
                  'uuid3',
                  '2',
                  'group-name2',
                  %w[12 15],
                  nil,
                  nil,
                  'net-name2',
                  '2',
                  'dep-name2',
                  'ip-addr3',
                  'bosh1.tld',
                  'fake-agent-uuid1',
                  3,
                ],
              ],
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
        end

        context 'canonicalization' do
          let(:network_name_hash) do
            { 'net-name1' => '1', 'net-name2' => '2', 'net_name3' => '3' }
          end
          before do
            dns_records.add_record(
              instance_id:         'uuid4',
              num_id:              3,
              index:               4,
              instance_group_name: 'group_name3',
              az_name:             'az3',
              network_name:        'net_name3',
              deployment_name:     'dep_name3',
              ip:                  'ip-addr4',
              domain:              'bosh3.tld',
              agent_id:            'fake-agent-uuid3',
            )
          end

          it 'canonicalizes the network name, deployment name and instance group name' do
            expected_records = {
              'records' => [
                ['ip-addr1', 'uuid1.group-name1.net-name1.dep-name1.bosh1.tld'],
                ['ip-addr2', 'uuid2.group-name2.net-name2.dep-name2.bosh1.tld'],
                ['ip-addr3', 'uuid3.group-name2.net-name2.dep-name2.bosh1.tld'],
                ['ip-addr4', 'uuid4.group-name3.net-name3.dep-name3.bosh3.tld'],
              ],
              'version' => 2,
              'aliases' => {},
              'record_keys' =>
                %w[id num_id instance_group group_ids az az_id network network_id deployment ip domain agent_id instance_index],
              'record_infos' => [
                [
                  'uuid1',
                  '0',
                  'group-name1',
                  %w[11],
                  'az1',
                  '3',
                  'net-name1',
                  '1',
                  'dep-name1',
                  'ip-addr1',
                  'bosh1.tld',
                  'fake-agent-uuid1',
                  1,
                ],
                [
                  'uuid2',
                  '1',
                  'group-name2',
                  %w[12 14],
                  'az2',
                  '7',
                  'net-name2',
                  '2',
                  'dep-name2',
                  'ip-addr2',
                  'bosh1.tld',
                  'fake-agent-uuid1',
                  2,
                ],
                [
                  'uuid3',
                  '2',
                  'group-name2',
                  %w[12 15],
                  nil,
                  nil,
                  'net-name2',
                  '2',
                  'dep-name2',
                  'ip-addr3',
                  'bosh1.tld',
                  'fake-agent-uuid1',
                  3,
                ],
                [
                  'uuid4',
                  '3',
                  'group-name3',
                  %w[13],
                  'az3',
                  '11',
                  'net-name3',
                  '3',
                  'dep-name3',
                  'ip-addr4',
                  'bosh3.tld',
                  'fake-agent-uuid3',
                  4,
                ],
              ],
            }
            expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
          end
        end
      end

      context 'with aliases' do
        before do
          dns_records.add_alias('my-service.my-domain', 'some-fqdn')
          dns_records.add_alias('my-service.my-domain', 'another-fqdn')
          dns_records.add_alias('another.another-domain', 'some-fqdn')
        end

        it 'returns json' do
          expected_records = {
            'records' => [],
            'version' => 2,
            'aliases' => {
              'my-service.my-domain' => ['some-fqdn', 'another-fqdn'],
              'another.another-domain' => ['some-fqdn'],
            },
            'record_infos' => [],
            'record_keys' => %w[
              id
              num_id
              instance_group
              group_ids
              az
              az_id
              network
              network_id
              deployment
              ip
              domain
              agent_id
              instance_index
            ],
          }
          expect(JSON.parse(dns_records.to_json)).to eq(expected_records)
        end
      end

      context 'when there are 0 records' do
        it 'returns empty json' do
          expect(JSON.parse(dns_records.to_json)).to match({
            records: [],
            version: 2,
            record_keys: %w[
              id
              num_id
              instance_group
              group_ids
              az
              az_id
              network
              network_id
              deployment
              ip
              domain
              agent_id
              instance_index
            ],
            record_infos: [],
            aliases: {},
          }.stringify_keys)
        end
      end
    end
  end
end
