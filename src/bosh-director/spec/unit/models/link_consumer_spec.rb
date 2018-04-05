require 'spec_helper'
require 'bosh/director/models/variable'

module Bosh::Director::Models::Links
  describe LinkConsumer do
    let(:deployment) {Bosh::Director::Models::Deployment.create(name: 'my-dep')}

    describe '#validate' do
      it 'validates presence of deployment_id' do
        expect {
          LinkConsumer.create(
            instance_group: 'ig',
            name: 'name',
            type: 'type'
          )
        }.to raise_error(Sequel::ValidationFailed, 'deployment_id presence')
      end

      it 'validates presence of name' do
        expect {
          LinkConsumer.create(
            deployment: deployment,
            instance_group: 'ig',
            type: 'type'
          )
        }.to raise_error(Sequel::ValidationFailed, 'name presence')
      end

      it 'validates presence of value' do
        expect {
          LinkConsumer.create(
            deployment: deployment,
            instance_group: 'ig',
            name: 'name'
          )
        }.to raise_error(Sequel::ValidationFailed, 'type presence')
      end
    end

    describe '#find_intent_by_name' do
      let(:link_consumer) do
        LinkConsumer.create(
          deployment: deployment,
          instance_group: 'ig',
          name: 'name',
          type: 'type'
        )
      end

      it 'return the correct intent by name' do
        link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: 'meow',
          type: 'meow-type'
        )
        expect(link_consumer.find_intent_by_name('meow')).to eq(link_consumer_intent)
      end
    end
  end
end
