require 'spec_helper'
require 'bosh/director/models/links/link'

module Bosh::Director::Models::Links
  describe LinkProviderIntent do
    describe '#validate' do
      it 'validates presence of original name' do
        expect do
          FactoryBot.create(:models_links_link_provider_intent,
            original_name: nil,
          )
        end.to raise_error(Sequel::ValidationFailed, 'original_name presence')
      end

      it 'validates presence of link_provider_id' do
        expect do
          FactoryBot.create(:models_links_link_provider_intent,
            link_provider: nil,
          )
        end.to raise_error(Sequel::ValidationFailed, 'link_provider_id presence')
      end

      it 'validates presence of type' do
        expect do
          FactoryBot.create(:models_links_link_provider_intent,
            type: nil,
          )
        end.to raise_error(Sequel::ValidationFailed, 'type presence')
      end
    end

    describe '#canonical_name' do
      context 'when the provider intent has an aliased name' do
        let(:provider_intent) { FactoryBot.create(:models_links_link_provider_intent, original_name: 'original', name: 'alias') }

        it 'returns the aliased name' do
          expect(provider_intent.canonical_name).to eq('alias')
        end
      end

      context 'when the provider intent does not have an aliased name' do
        let(:provider_intent) { FactoryBot.create(:models_links_link_provider_intent, original_name: 'original', name: nil) }

        it 'returns the original name' do
          expect(provider_intent.canonical_name).to eq('original')
        end
      end
    end

    describe '#group_name' do
      context 'when provider intent has an aliased name and a type' do
        let(:provider_intent) { FactoryBot.create(:models_links_link_provider_intent, original_name: 'original', name: 'alias', type: 'type1') }

        it 'returns a combination of aliased name and link type' do
          expect(provider_intent.group_name).to eq('alias-type1')
        end
      end

      context 'when provider intent does not have an aliased name' do
        let(:provider_intent) { FactoryBot.create(:models_links_link_provider_intent, original_name: 'original', name: nil, type: 'type1') }

        it 'returns a combination of provider original name and link type' do
          expect(provider_intent.group_name).to eq('original-type1')
        end
      end
    end
  end
end
