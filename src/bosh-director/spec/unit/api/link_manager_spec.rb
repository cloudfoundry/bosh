require 'spec_helper'

module Bosh::Director
  describe Api::LinkManager do

    let(:username) { 'LINK_CREATOR' }
    let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'})) }
    let(:provider_1) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment,
        instance_group: 'instance_group',
        name: 'provider_name_1',
        type: 'job',
        shared: true,
        consumable: true,
        type: 'link_type_1',
      )
    end
    let(:provider_1_intent_1) do
      Models::Links::LinkProviderIntent.create(
        :name => 'link_name_1',
        :link_provider => provider_1,
        :shared => true,
        :consumable => true,
        :type => 'link_type_1',
        :original_name => 'provider_name_1',
        :content => 'some link content',
        )
    end
    let(:consumer_1) do
      Models::Links::LinkConsumer.create(
        :deployment => deployment,
        :instance_group => 'instance_group',
        :type => 'external',
        :name => 'external_consumer_1',
        )
    end
    let(:consumer_1_intent_1) do
      Models::Links::LinkConsumerIntent.create(
        :link_consumer => consumer_1,
        :original_name => 'provider_name_1',
        :type => 'job',
        :optional => false,
        :blocked => false,
        )
    end
    let(:link_1) do
      Models::Links::Link.create(
        :name => 'link_1',
        :link_provider_intent_id => provider_1_intent_1.id,
        :link_consumer_intent_id => consumer_1_intent_1.id,
        :link_content => "some link content",
        :created_at => Time.now
      )
    end

    let(:payload_json) do
       {
          'link_provider_id'=> provider_id,
          'link_consumer' => {
            'owner_object_name'=> 'external_consumer_1',
            'owner_object_type'=> 'external',
          }
       }
    end
    let(:provider_id) {provider_1.id}

    describe '#create_link' do
      context 'when link_provider_id is invalid' do
        let(:provider_id) {2}
        it 'return error' do
          expect { subject.create_link(username, payload_json) }.to raise_error(RuntimeError, /Invalid link_provider_id: 2/)
        end
      end
      context 'when link_provider_id is missing' do
        let(:provider_id) { "" }
        it 'return error' do
          expect { subject.create_link(username, payload_json) }.to raise_error(RuntimeError, /Invalid json: provide valid `link_provider_id`/)
        end
      end

      context 'when provider is valid' do
        it '#find_provider and #find_provider_intent' do
          expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).and_return([provider_1])
          expect(Bosh::Director::Models::Links::LinkProviderIntent).to receive(:find).and_return(provider_1_intent_1)

          subject.create_link(username, payload_json)
        end
      end

      context 'when link_consumer data is invalid' do
        context 'when link_consumer is missing from inputs' do
          let(:payload_json) do
            {
              'link_provider_id'=> provider_id,
            }
          end
          it 'return error' do
            expect { subject.create_link(username, payload_json) }.to raise_error(/Invalid json: missing `link_consumer`/)
          end
        end

        context 'when link_consumer contents are invalid' do
          #TODO Links: make sure the empty string get removed from the json object Ex: {"owner_object_name"=>""}
          let(:payload_json) do
            {
              'link_provider_id'=> provider_id,
              'link_consumer' => {"owner_object_name"=>""}
            }
          end
          it 'return error' do
            expect { subject.create_link(username, payload_json) }.to raise_error(/Invalid json: provide valid `owner_object_name`/)
          end
        end
      end

      context 'when link_conumer data in valid' do
        before do
          allow(Bosh::Director::Models::Links::LinkConsumer).to receive(:find_or_create).and_return(consumer_1)
          allow(Bosh::Director::Models::Links::LinkConsumerIntent).to receive(:find_or_create).and_return(consumer_1_intent_1)
          allow(Bosh::Director::Models::Links::Link).to receive(:find_or_create).and_return(link_1)
        end
        it '#create_consumers and #create_consumer_intent' do
          expect(Bosh::Director::Models::Links::LinkConsumer).to receive(:find_or_create).and_return(consumer_1)
          expect(Bosh::Director::Models::Links::LinkConsumerIntent).to receive(:find_or_create).and_return(consumer_1_intent_1)
          subject.create_link(username, payload_json)
        end

        it '#create_external_link' do
          actual_link = Bosh::Director::Models::Links::Link.find(
            link_provider_intent_id: provider_1_intent_1.id,
            link_consumer_intent_id: consumer_1_intent_1.id,
            name: 'link_1'
            )
          subject.create_link(username, payload_json)
          expect(actual_link).to eq(link_1)
        end
      end

    end

    describe '#delete_links' do

    end

  end
end
