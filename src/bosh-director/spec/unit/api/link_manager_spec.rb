require 'spec_helper'

module Bosh::Director
  describe Api::LinkManager do
    let(:username) { 'LINK_CREATOR' }
    let(:link_serial_id) { 42 }
    let(:deployment) { Models::Deployment.create(name: 'test_deployment', manifest: YAML.dump('foo' => 'bar'), links_serial_id: link_serial_id) }
    let(:instance_group) { 'instance_group' }
    let(:networks) { %w[neta netb] }
    let(:provider_json_content) do
      {
        default_network: 'netb',
        networks: networks,
        instances: [
          {
            dns_addresses: { neta: 'dns1', netb: 'dns2' },
            addresses: { neta: 'ip1', netb: 'ip2' },
          },
        ],
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
        name: 'link_name_1',
        link_provider: provider_1,
        shared: true,
        consumable: true,
        type: 'job',
        original_name: 'provider_name_1',
        content: provider_json_content.to_json,
        serial_id: link_serial_id,
      )
    end
    let(:payload_json) do
      {
        'link_provider_id' => provider_id,
        'link_consumer' => {
          'owner_object_name' => 'external_consumer_1',
          'owner_object_type' => 'external',
        },
      }
    end
    let(:provider_id) { provider_1_intent_1.id }

    describe '#create_link' do
      shared_examples 'creates consumer, consumer_intent and link' do
        it '#filter_content_and_create_link' do
          subject.create_link(username, payload_json)

          external_consumer = Bosh::Director::Models::Links::LinkConsumer.find(
            deployment: deployment,
            instance_group: instance_group,
            name: 'external_consumer_1',
            type: 'external',
          )
          expect(external_consumer).to_not be_nil

          external_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
            link_consumer: external_consumer,
            original_name: provider_1.name,
          )
          expect(external_consumer_intent).to_not be_nil
          expect(external_consumer_intent.type).to eq(provider_1_intent_1.type)

          external_link = Bosh::Director::Models::Links::Link.find(
            link_provider_intent_id: provider_1_intent_1.id,
            link_consumer_intent_id: external_consumer_intent.id,
            name: provider_1.name,
          )
          expect(external_link).to_not be_nil
          expect(JSON.parse(external_link.link_content)).to match('default_network' => String, 'networks' => %w[neta netb], 'instances' => [{ 'address' => 'ip2' }])
        end
      end

      context 'when link_provider_id is invalid' do
        let(:provider_id) { 42 }
        it 'return error' do
          expect { subject.create_link(username, payload_json) }.to raise_error(RuntimeError, /Invalid link_provider_id: #{provider_id}/)
        end
      end

      context 'when link_provider_id is missing' do
        let(:provider_id) { '' }
        it 'return error' do
          expect { subject.create_link(username, payload_json) }.to raise_error(RuntimeError, /Invalid request: `link_provider_id` must be an Integer/)
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
              'link_provider_id' => provider_id,
            }
          end

          it 'return error' do
            expect { subject.create_link(username, payload_json) }.to raise_error(/Invalid request: `link_consumer` section must be defined/)
          end
        end

        context 'when link_consumer contents are invalid' do
          context 'invalid owner_object_name' do
            let(:payload_json) do
              {
                'link_provider_id' => provider_id,
                'link_consumer' => {
                  'owner_object_name' => '',
                  'owner_object_type' => 'external',
                },
              }
            end

            it 'return error' do
              expect { subject.create_link(username, payload_json) }.to raise_error(/Invalid request: `link_consumer.owner_object_name` must not be empty/)
            end
          end

          context 'invalid owner_object_type' do
            let(:payload_json) do
              {
                'link_provider_id' => provider_id,
                'link_consumer' => {
                  'owner_object_name' => 'test_owner_name',
                  'owner_object_type' => 'test_owner_type',
                },
              }
            end

            it 'return error' do
              expect { subject.create_link(username, payload_json) }.to raise_error(/Invalid request: `link_consumer.owner_object_type` should be 'external'/)
            end
          end
        end
      end

      context 'when link_consumer data is valid' do
        let(:consumer_1) {}
        let(:consumer_1_intent_1) {}
        let(:link_1) {}

        context '#filter_content_and_create_link' do
          include_examples 'creates consumer, consumer_intent and link'
        end

        context 'when provider type and provider_intent types are different' do
          let(:provider_1_intent_1) do
            Models::Links::LinkProviderIntent.create(
              name: 'link_name_1',
              link_provider: provider_1,
              shared: true,
              consumable: true,
              type: 'different-job-type',
              original_name: 'provider_name_1',
              content: provider_json_content.to_json,
              serial_id: link_serial_id,
            )
          end

          include_examples 'creates consumer, consumer_intent and link'
        end

        context 'when network is provided' do
          let(:network_name) { networks[0] }
          let(:payload_json) do
            {
              'link_provider_id' => provider_id,
              'link_consumer' => {
                'owner_object_name' => 'external_consumer_1',
                'owner_object_type' => 'external',
              },
              'network' => network_name,
            }
          end

          context 'when network is valid' do
            include_examples 'creates consumer, consumer_intent and link'
          end

          context 'when network in invalid' do
            let(:network_name) { 'invalid_network_name' }

            it 'return error' do
              expect { subject.create_link(username, payload_json) }.to raise_error(/Can't resolve network: `invalid_network_name` in provider id: 1 for `external_consumer_1`/)
            end
          end
        end
      end
    end

    describe '#delete_link' do
      context 'when link_id is invalid' do
        let!(:not_external_consumer_1) do
          Models::Links::LinkConsumer.create(
            deployment: deployment,
            instance_group: 'instance_group',
            type: 'job',
            name: 'job_name_1',
            serial_id: link_serial_id,
          )
        end

        let!(:not_external_consumer_intent_1) do
          Models::Links::LinkConsumerIntent.create(
            link_consumer: not_external_consumer_1,
            original_name: 'link_1',
            type: 'link_type_1',
            name: 'link_alias_1',
            optional: false,
            blocked: false,
            serial_id: link_serial_id,
          )
        end
        let!(:not_external_link_1) do
          Models::Links::Link.create(
            name: 'link_1',
            link_provider_intent_id: provider_1_intent_1.id,
            link_consumer_intent_id: not_external_consumer_intent_1.id,
            link_content: 'content 1',
            created_at: Time.now,
          )
        end
        context 'when link is not external' do
          let(:link_id) { not_external_link_1.id }
          it 'return error' do
            expect { subject.delete_link(username, link_id) }.to raise_error(LinkNotExternalError, /Error deleting link: not a external link/)
          end
        end

        context 'when link_id is non-existing' do
          let(:link_id) { 42 + not_external_link_1.id }
          it 'return error' do
            expect { subject.delete_link(username, link_id) }.to raise_error(LinkLookupError, "Invalid link id: #{link_id}")
          end
        end
      end

      context 'when link id is valid' do
        context 'when link is not created by the user' do
          it 'return access error' do
            # TODO: Links: need to discuss more about the access filter
          end
        end

        context 'when link is external' do
          let(:deployment) do
            Bosh::Director::Models::Deployment.make
          end

          let(:external_consumer) do
            Bosh::Director::Models::Links::LinkConsumer.create(
              deployment: deployment,
              instance_group: 'provider_ig_name',
              name: 'provider_job_name',
              type: 'external',
            )
          end

          let(:external_consumer_intent) do
            Bosh::Director::Models::Links::LinkConsumerIntent.create(
              link_consumer: external_consumer,
              original_name: 'link_name',
              type: 'link_type',
            )
          end

          let!(:external_link) do
            Bosh::Director::Models::Links::Link.create(
              link_consumer_intent: external_consumer_intent,
              link_content: '{}',
              name: 'link_name',
            )
          end

          context 'when there are multiple external consumers' do
            before do
              control_consumer = Bosh::Director::Models::Links::LinkConsumer.create(
                deployment: deployment,
                instance_group: 'control_ig_name',
                name: 'control_job_name',
                type: 'external',
              )

              control_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
                link_consumer: control_consumer,
                original_name: 'control_consumer_intent',
                type: 'control_type',
              )

              Bosh::Director::Models::Links::Link.create(
                link_consumer_intent: control_consumer_intent,
                link_content: '{}',
                name: 'control_consumer_link',
              )
            end

            it 'only deletes the link with specific id' do
              expect(Bosh::Director::Models::Links::LinkConsumer.count).to eq(2)
              expect(Bosh::Director::Models::Links::LinkConsumerIntent.count).to eq(2)
              expect(Bosh::Director::Models::Links::Link.count).to eq(2)

              expect do
                subject.delete_link(username, external_link[:id])
              end.to_not raise_error

              expect(Bosh::Director::Models::Links::LinkConsumer.count).to eq(1)
              expect(Bosh::Director::Models::Links::LinkConsumerIntent.count).to eq(1)
              expect(Bosh::Director::Models::Links::Link.count).to eq(1)
              expect(Bosh::Director::Models::Links::Link.find(name: 'control_consumer_link')).to_not(be_nil)
            end
          end

          context 'when there is a single external consumer' do
            context 'when there are multiple intents for the consumer' do
              before do
                control_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
                  link_consumer: external_consumer,
                  original_name: 'control_consumer_intent',
                  type: 'control_type',
                )

                Bosh::Director::Models::Links::Link.create(
                  link_consumer_intent: control_consumer_intent,
                  link_content: '{}',
                  name: 'control_consumer_link',
                )
              end

              it 'only deletes the link with specific id' do
                expect(Bosh::Director::Models::Links::LinkConsumer.count).to eq(1)
                expect(Bosh::Director::Models::Links::LinkConsumerIntent.count).to eq(2)
                expect(Bosh::Director::Models::Links::Link.count).to eq(2)

                expect do
                  subject.delete_link(username, external_link[:id])
                end.to_not raise_error

                expect(Bosh::Director::Models::Links::LinkConsumer.count).to eq(1)
                expect(Bosh::Director::Models::Links::LinkConsumerIntent.count).to eq(1)
                expect(Bosh::Director::Models::Links::Link.count).to eq(1)
                expect(Bosh::Director::Models::Links::Link.find(name: 'control_consumer_link')).to_not(be_nil)
              end
            end

            context 'when there is a single intent for the consumer' do
              before do
                Bosh::Director::Models::Links::Link.create(
                  link_consumer_intent: external_consumer_intent,
                  link_content: '{}',
                  name: 'control_consumer_link',
                )
              end

              it 'only deletes the link with specific id' do
                expect(Bosh::Director::Models::Links::LinkConsumer.count).to eq(1)
                expect(Bosh::Director::Models::Links::LinkConsumerIntent.count).to eq(1)
                expect(Bosh::Director::Models::Links::Link.count).to eq(2)

                expect do
                  subject.delete_link(username, external_link[:id])
                end.to_not raise_error

                expect(Bosh::Director::Models::Links::LinkConsumer.count).to eq(1)
                expect(Bosh::Director::Models::Links::LinkConsumerIntent.count).to eq(1)
                expect(Bosh::Director::Models::Links::Link.count).to eq(1)
                expect(Bosh::Director::Models::Links::Link.find(name: 'control_consumer_link')).to_not(be_nil)
              end
            end
          end
        end
      end
    end
  end
end
