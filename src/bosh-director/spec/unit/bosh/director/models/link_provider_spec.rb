require 'spec_helper'
require 'bosh/director/models/variable'

module Bosh::Director::Models::Links
  describe LinkProvider do
    let(:deployment) {Bosh::Director::Models::Deployment.create(name: 'my-dep')}

    describe '#validate' do
      it 'validates presence of deployment_id' do
        expect {
          LinkProvider.create(
            instance_group: 'ig',
            name: 'name',
            type: 'type'
          )
        }.to raise_error(Sequel::ValidationFailed, 'deployment_id presence')
      end

      it 'validates presence of instance_group' do
        expect {
          Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment,
            name: 'name',
            type: 'type'
          )
        }.to raise_error(Sequel::ValidationFailed, 'instance_group presence')
      end

      it 'validates presence of name' do
        expect {
          LinkProvider.create(
            deployment: deployment,
            instance_group: 'ig',
            type: 'type'
          )
        }.to raise_error(Sequel::ValidationFailed, 'name presence')
      end

      it 'validates presence of value' do
        expect {
          LinkProvider.create(
            deployment: deployment,
            instance_group: 'ig',
            name: 'name'
            )
        }.to raise_error(Sequel::ValidationFailed, 'type presence')
      end
    end

    describe '#find_intent_by_name' do
      let(:link_provider) do
        LinkProvider.create(
          deployment: deployment,
          instance_group: 'ig',
          name: 'name',
          type: 'type'
        )
      end

      it 'return the correct intent by name' do
        link_provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'meow',
          type: 'meow-type'
        )
        expect(link_provider.find_intent_by_name('meow')).to eq(link_provider_intent)
      end
    end
  end
end
