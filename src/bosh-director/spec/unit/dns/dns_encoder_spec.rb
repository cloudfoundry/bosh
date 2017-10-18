require 'spec_helper'

module Bosh::Director
  describe DnsEncoder do
    subject { described_class.new(service_groups, az_hash, network_name_hash, short_dns_enabled) }
    let(:az_hash) {}
    let(:network_name_hash) {}
    let(:short_dns_enabled) { false }
    let(:instance_group) { 'potato-group' }
    let(:default_network) { 'potato-net' }
    let(:deployment_name) { 'fake-deployment' }
    let(:root_domain) { 'sub.bosh' }
    let(:specific_query) { {} }
    let(:criteria) do
      {
        instance_group: instance_group,
        default_network: default_network,
        deployment_name: deployment_name,
        root_domain: root_domain
      }.merge(specific_query)
    end

    let(:service_groups) {{
      { instance_group: 'potato-group',
        deployment:     'fake-deployment',
      } => 3,
      { instance_group: 'lemon-group',
        deployment:     'fake-deployment',
      } => 7,
    }}


    describe '#encode_query' do
      context 'no filters' do
        it 'always includes health code in query with default healthy' do
          expect(subject.encode_query(criteria)).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
        end
      end

      describe 'encoding AZ indices' do
        let(:az_hash) { { 'zone1' => '1', 'zone2' => '2' } }

        context 'single az filter' do
          let(:specific_query) { {azs: ['zone1']} }
          it 'includes an a# code' do
            expect(subject.encode_query(criteria)).to eq('q-a1s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end

        context 'multiple az filter' do
          let(:specific_query) { {azs: ['zone2','zone1']} }
          it 'includes all the codes in order' do
            expect(subject.encode_query(criteria)).to eq('q-a1a2s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end
        end
      end

      describe 'short DNS names enabled by providing service groups' do
        let(:short_dns_enabled) { true }
        it 'produces an abbreviated address with three octets' do
          expect(subject.encode_query(criteria)).to eq('q-s0.g-3.sub.bosh')
        end

        it 'chooses from among all known service groups' do
          criteria[:instance_group] = 'lemon-group'
          criteria[:default_network] = 'surprise-network'
          expect(subject.encode_query(criteria)).to eq('q-s0.g-7.sub.bosh')
        end
      end
    end

    describe '#id_for_group_tuple' do
      context 'when short dns is enabled' do
        let(:short_dns_enabled) { true }
        it 'can look up the group id' do
          expect(subject.id_for_group_tuple(
            'potato-group',
            'fake-deployment'
          )).to eq '3'
          expect(subject.id_for_group_tuple(
            'lemon-group',
            'fake-deployment'
          )).to eq '7'
        end
      end
      context 'even when short dns is not enabled' do
        it 'can still look up the group id' do
          expect(subject.id_for_group_tuple(
            'potato-group',
            'fake-deployment'
          )).to eq '3'
          expect(subject.id_for_group_tuple(
            'lemon-group',
            'fake-deployment'
          )).to eq '7'
        end
      end
    end

    describe '#id_for_az' do
      let(:az_hash) { { 'zone1' => '1', 'zone2' => '2' } }

      it 'matches if found' do
        expect(subject.id_for_az('zone1')).to eq('1')
        expect(subject.id_for_az('zone2')).to eq('2')
      end

      it 'raises exception if not found' do
        expect {
          subject.id_for_az('zone3')
        }.to raise_error(RuntimeError, "Unknown AZ: 'zone3'")
      end

      it 'returns nil if az is nil' do
        expect(subject.id_for_az(nil)).to eq(nil)
      end
    end

    describe '#id_for_network' do
      let(:network_name_hash) { { 'nw1' => '1', 'nw2' => '2' } }

      it 'matches if found' do
        expect(subject.id_for_network('nw1')).to eq('1')
        expect(subject.id_for_network('nw2')).to eq('2')
      end

      it 'raises exception if not found' do
        expect {
          subject.id_for_network('nw3')
        }.to raise_error(RuntimeError, "Unknown Network: 'nw3'")
      end

      it 'returns nil if network name is nil' do
        expect(subject.id_for_network(nil)).to eq(nil)
      end
    end
  end
end
