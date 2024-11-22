require 'spec_helper'

module Bosh
  module Template
    describe EvaluationLink do
      describe '#address' do
        let(:subject) do
          EvaluationLink.new(
            instances,
            properties,
            group_name,
            group_type,
            default_network,
            deployment,
            root_domain,
            dns_encoder,
            use_short_dns,
          )
        end
        let(:instances) { [] }
        let(:properties) do
          {}
        end
        let(:group_name) { 'potato_group' }
        let(:group_type) { 'spud' }
        let(:default_network) { 'potato_net' }
        let(:deployment) { 'fake_deployment' }
        let(:root_domain) { 'sub.bosh' }
        let(:use_short_dns) { false }
        let(:dns_encoder) { double('FAKE_DNS_ENCODER') }

        describe '#address' do
          it 'resolves the link characteristics and query params using the dns resolver' do
            allow(dns_encoder).to receive(:encode_query).with(
              hash_including(
                azs: %w[zone1],
                group_name: group_name,
                group_type: group_type,
              ),
              false,
            ).and_return('q-a0s0.potato-group.potato-net.fake-deployment.sub.bosh')
            expect(subject.address(azs: ['zone1'])).to eq('q-a0s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end

          it 'allows you to specify healthiness in your query' do
            allow(dns_encoder).to receive(:encode_query).with(
              hash_including(status: 'default'),
              false,
            ).and_return('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
            expect(subject.address(status: 'default')).to eq('q-s0.potato-group.potato-net.fake-deployment.sub.bosh')
          end

          context 'when use short dns is enabled' do
            let(:use_short_dns) { true }

            it 'resolves the address to a short dns name' do
              expect(dns_encoder).to receive(:encode_query).with(hash_including(azs: ['zone1']), true)
              subject.address(azs: ['zone1'])
            end
          end

          context 'when there is no dns resolver' do
            let(:dns_encoder) { nil }
            it 'raises an error' do
              expect do
                expect(subject.address(azs: ['zone1']))
              end.to raise_error NotImplementedError, 'link.address requires bosh director'
            end
          end
        end

        context 'when properties are defined' do
          let(:properties) do
            {
              'prop1' => {
                'nested1' => 'val1',
                'nested2' => 'val2',
              },
              'prop2' => {
                'nested3' => 'val3',
              },
              'prop3' => {
                'nested4' => 'val4',
              },
            }
          end

          context 'p' do
            it 'can find a property' do
              expect(subject.p('prop1.nested2')).to eq('val2')
              expect(subject.p('prop2.nested3')).to eq('val3')
            end

            it 'raises an error when asked for a property which does not exist' do
              expect do
                subject.p('vroom')
              end.to raise_error Bosh::Template::UnknownProperty,
                                 "Can't find property '[\"vroom\"]'"
            end

            it 'allows setting a default instead of raising an error if the key is not found' do
              expect(subject.p('prop1.nestedX', 'default_value')).to eq('default_value')
            end

            it 'raises an UnknownProperty error if you pass more than two' \
               ' arguments and the first one is not present' do
              expect do
                subject.p('vroom', 'vroom', 'vroom')
              end.to raise_error Bosh::Template::UnknownProperty,
                                 "Can't find property '[\"vroom\"]'"
            end
          end

          context 'if_p' do
            let(:active_else_block)   { double(:active_else_block) }
            let(:inactive_else_block) { double(:inactive_else_block) }

            before do
              allow(Bosh::Template::EvaluationContext::ActiveElseBlock).to receive(:new)
                .with(subject)
                .and_return active_else_block
              allow(Bosh::Template::EvaluationContext::InactiveElseBlock).to receive(:new)
                .and_return inactive_else_block
            end

            it 'returns an active else block if any of the properties are not present' do
              expect(
                subject.if_p('prop1.nested1', 'prop2.doesntexist') {},
              ).to eq(active_else_block)
            end

            it 'yields the values of the requested properties' do
              subject.if_p('prop1.nested1', 'prop1.nested2', 'prop2.nested3') do |*values|
                expect(values).to eq(%w[val1 val2 val3])
              end
            end

            it 'returns an inactive else block' do
              expect(
                subject.if_p('prop1.nested1') {},
              ).to eq(inactive_else_block)
            end
          end
        end
      end
    end
  end
end
