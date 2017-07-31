require 'spec_helper'
require 'bosh/template/evaluation_link'

module Bosh
  module Template
    describe EvaluationLink do
      describe '#address' do
        let(:subject) { EvaluationLink.new(instances, properties, instance_group, default_network, deployment, root_domain, dns_encoder) }
        let(:instances) { [] }
        let(:properties) { {} }
        let(:instance_group) { 'potato_group' }
        let(:default_network) { 'potato_net' }
        let(:deployment) { 'fake_deployment' }
        let(:root_domain) { 'sub.bosh' }
        let(:dns_encoder) { double 'some dns encoder' }

        it 'resolves the link characteristics and query params using the dns resolver' do
          expect(dns_encoder).to receive(:encode_query).with(
            instance_group: instance_group,
            default_network: default_network,
            deployment: deployment,
            root_domain: root_domain,
            azs: ['zone1'],
          ).and_return('potato')

          expect(subject.address(azs: ['zone1'])).to eq('potato')
        end

        context 'when there is no dns resolver' do
          let(:dns_encoder) { nil }
          it 'raises an error' do
            expect {
              expect(subject.address(azs: ['zone1'])).to eq('potato')
            }.to raise_error NotImplementedError, 'link.address requires bosh director'
          end
        end
      end
    end
  end
end
