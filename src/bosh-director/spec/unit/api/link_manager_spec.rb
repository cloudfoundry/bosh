require 'spec_helper'

module Bosh::Director
  describe Api::LinkManager do

    let(:username) { 'LINK_CREATOR' }
    let(:link_serial_id) { 42 }
    let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'}), :links_serial_id => link_serial_id) }
    let(:instance_group) {'instance_group'}
    let(:networks) { ['neta', 'netb'] }
    let(:provider_json_content) do
       {
          default_network: 'netb',
          networks: networks,
          instances: [
            {
              dns_addresses: {neta: 'dns1', netb: 'dns2'},
              addresses: {neta: 'ip1', netb: 'ip2'}
            }
          ]
       }
    end
    let(:provider_1) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment,
        instance_group: instance_group,
        name: 'provider_name_1',
        type: 'job',
        serial_id: link_serial_id,
      )
    end
    let(:provider_1_intent_1) do
      Models::Links::LinkProviderIntent.create(
        :name => 'link_name_1',
        :link_provider => provider_1,
        :shared => true,
        :consumable => true,
        :type => 'job',
        :original_name => 'provider_name_1',
        :content => provider_json_content.to_json,
        :serial_id => link_serial_id,
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
    let(:provider_id) {provider_1_intent_1.id}

    describe '#create_link' do
      context 'when link_provider_id is invalid' do
        let(:provider_id) { 42 }
        it 'return error' do
          expect { subject.create_link(username, payload_json) }.to raise_error(RuntimeError, /Invalid link_provider_id: #{provider_id}/)
        end
      end
      context 'when link_provider_id is missing' do
        let(:provider_id) { "" }
        it 'return error' do
          expect { subject.create_link(username, payload_json) }.to raise_error(RuntimeError, /Invalid json: provide valid `link_provider_id`/)
        end
      end

      context 'when provider_id (provider_intent_id) is valid' do
        it '#find_provider_intent' do
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
        let(:consumer_1) {}
        let(:consumer_1_intent_1) {}
        let(:link_1) {}

        shared_examples 'creates consumer, consumer_intent and link' do
          it '#filter_content_and_create_link' do
            subject.create_link(username, payload_json)

            actual_consumer = Bosh::Director::Models::Links::LinkConsumer.find(
              deployment: deployment,
              instance_group: instance_group,
              name: "external_consumer_1",
              type: "external"
            )
            expect(actual_consumer).to_not be_nil

            actual_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
              link_consumer: actual_consumer,
              original_name: provider_1.name
            )
            expect(actual_consumer_intent).to_not be_nil
            expect(actual_consumer_intent.type).to eq(provider_1_intent_1.type)

            actual_link = Bosh::Director::Models::Links::Link.find(
              link_provider_intent_id: provider_1_intent_1.id,
              link_consumer_intent_id: actual_consumer_intent.id,
              name: provider_1.name
            )
            expect(actual_link).to_not be_nil
            expect(JSON.parse(actual_link.link_content)).to match({'default_network' => String, 'networks' => ['neta', 'netb'], 'instances' => [{'address' => 'ip2'}]})
          end

        end

        context '#filter_content_and_create_link' do
          include_examples 'creates consumer, consumer_intent and link'
        end

        context 'when provider type and provider_intent types are different' do
          let(:provider_1_intent_1) do
            Models::Links::LinkProviderIntent.create(
              :name => 'link_name_1',
              :link_provider => provider_1,
              :shared => true,
              :consumable => true,
              :type => 'different-job-type',
              :original_name => 'provider_name_1',
              :content => provider_json_content.to_json,
              :serial_id => link_serial_id,
              )
          end

          include_examples 'creates consumer, consumer_intent and link'
        end

        context 'when network is provided' do
          let(:network_name) { networks[0]}
          let(:payload_json) do
            {
              'link_provider_id'=> provider_id,
              'link_consumer' => {
                'owner_object_name'=> 'external_consumer_1',
                'owner_object_type'=> 'external',
              },
              'network' => network_name,
            }
          end

          context 'when network is valid' do
            include_examples 'creates consumer, consumer_intent and link'
          end

          context 'when network in invalid' do
            let(:network_name) { "invalid_network_name"}

            it 'return error' do
              expect { subject.create_link(username, payload_json) }.to raise_error(/Can't resolve network: `invalid_network_name` in provider id: 1 for `external_consumer_1`/)
            end
          end
        end
      end
    end
  end
end
