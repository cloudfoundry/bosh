require 'spec_helper'
require 'bosh/director/models/variable'

module Bosh::Director::Models::Links
  describe LinkConsumerIntent do
    let(:consumer) { LinkConsumer.create(deployment: deployment, name: 'test', type: 'job') }
    let(:deployment) { Bosh::Director::Models::Deployment.create(name: 'test') }
    let(:subject) { LinkConsumerIntent.create(link_consumer: consumer, original_name: 'test', type: 'db') }

    context '#target_link_id=' do
      it 'should set the target link id' do
        subject.target_link_id = 5
        expect(subject.target_link_id).to eq(5)
      end
    end

    context '#target_link_id' do
      let!(:link1) { Link.create(name: 'link', link_consumer_intent: subject, link_content: '{}') }
      let!(:link2) { Link.create(name: 'link', link_consumer_intent: subject, link_content: '{}') }

      it 'should return the target link id defined in the metadata' do
        subject.metadata = { explicit_link: true, target_link_id: 5 }.to_json
        subject.save
        expect(subject.target_link_id).to eq(5)
      end

      context 'when there is no metadata' do
        it 'should return fallback link id' do
          expect(subject.target_link_id).to eq(link2.id)
        end
      end

      context 'when there is no target_link_id defined' do
        it 'should return fallback link id' do
          subject.metadata = { explicit_link: true }.to_json
          subject.save
          expect(subject.target_link_id).to eq(link2.id)
        end
      end
    end
  end
end
