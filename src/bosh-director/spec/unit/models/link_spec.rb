require 'spec_helper'
require 'bosh/director/models/links/link'

module Bosh::Director::Models::Links
  describe Link do
    describe '#validate' do
      it 'validates presence of name' do
        expect do
          Link.create(
            link_consumer_intent_id: 1,
            link_content: '{}',
          )
        end.to raise_error(Sequel::ValidationFailed, 'name presence')
      end

      it 'validates presence of link_consumer_intent_id' do
        expect do
          Link.create(
            name: 'name',
            link_content: '{}',
          )
        end.to raise_error(Sequel::ValidationFailed, 'link_consumer_intent_id presence')
      end

      it 'validates presence of link_content' do
        expect do
          Link.create(
            name: 'name',
            link_consumer_intent_id: 1,
          )
        end.to raise_error(Sequel::ValidationFailed, 'link_content presence')
      end
    end

    describe '#group_name' do
      subject(:link) { Link.make }

      context 'when provider intent has a name and a type' do
        before do
          link.link_provider_intent = LinkProviderIntent.make(name: 'name', type: 'type')
          link.save
        end

        it 'returns a combination of provider name and link type' do
          expect(link.group_name).to eq('name-type')
        end
      end

      context 'when provider intent does not have a name' do
        before do
          link.link_provider_intent = LinkProviderIntent.make(name: nil, original_name: 'original_name', type: 'type')
          link.save
        end

        it 'returns a combination of provider original name and link type' do
          expect(link.group_name).to eq('original_name-type')
        end
      end

      context 'when provider intent is not set' do
        it 'returns blank' do
          expect(link.group_name).to eq('')
        end
      end
    end
  end
end
