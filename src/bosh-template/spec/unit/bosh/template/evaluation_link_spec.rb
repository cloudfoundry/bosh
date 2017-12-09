require 'spec_helper'
require 'bosh/template/evaluation_link'
require 'bosh/director/dns/dns_encoder'
require 'bosh/director/dns/canonicalizer'

module Bosh
  module Template
    describe EvaluationLink do
      describe '#address' do
        let(:subject) do
          EvaluationLink.new(
            instances,
            properties,
            instance_group,
            default_network,
            deployment,
            root_domain,
            dns_encoder,
          )
        end
        let(:instances) { [] }
        let(:properties) { {} }
        let(:instance_group) { 'potato_group' }
        let(:default_network) { 'potato_net' }
        let(:deployment) { 'fake_deployment' }
        let(:root_domain) { 'sub.bosh' }
        let(:dns_encoder) { Bosh::Director::DnsEncoder.new({},{'zone1' => '0'}) }

        it 'resolves the link characteristics and query params using the dns resolver' do
          expect(subject.address(azs: ['zone1'])).to eq('q-a0s0.potato-group.potato-net.fake-deployment.sub.bosh')
        end

        it 'allows you to specify healthiness in your query' do
          allow(dns_encoder).to receive(:encode_query).and_call_original
          expect(subject.address(status: 'default')).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
          expect(dns_encoder).to have_received(:encode_query).with(hash_including(status: 'default'))
        end

        context 'when there is no dns resolver' do
          let(:dns_encoder) { nil }
          it 'raises an error' do
            expect {
              expect(subject.address(azs: ['zone1']))
            }.to raise_error NotImplementedError, 'link.address requires bosh director'
          end
        end
      end
    end
  end
end
