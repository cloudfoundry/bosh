require 'spec_helper'
require 'bosh/director/models/variable'

module Bosh::Director::Models::Links
  describe LinkConsumerIntent do
    let(:consumer) { LinkConsumer.create(deployment: deployment, name: 'test', type: 'job') }
    let(:deployment) { Bosh::Director::Models::Deployment.create(name: 'test') }
    let(:subject) { LinkConsumerIntent.create(link_consumer: consumer, original_name: 'test', type: 'db') }

    it 'should set the target link id' do
      subject.target_link_id = 5
      expect(subject.target_link_id).to eq(5)
    end

    context 'when there is no target link id set' do
      before do
        Link.create(name: 'link', link_consumer_intent: subject, link_content: '{}')
        Link.create(name: 'link', link_consumer_intent: subject, link_content: '{}')
      end

      it 'should fall back to the latest link id' do
        expect(subject.target_link_id).to eq(2)
      end
    end
  end
end
