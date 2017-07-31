require 'spec_helper'

module Bosh::Director
  describe DnsEncoder do
    subject { described_class.new(az_hash) }
    let(:az_hash) {}

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
  end
end
