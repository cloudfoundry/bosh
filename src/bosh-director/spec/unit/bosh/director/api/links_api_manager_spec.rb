require 'spec_helper'

module Bosh::Director
  describe Api::LinksApiManager do
    let(:link_serial_id) { 7654321 }
    let(:deployment) do
      Models::Deployment.create(name: 'test_deployment', manifest: YAML.dump('foo' => 'bar'), links_serial_id: link_serial_id)
    end
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
        name: 'provider_name',
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
        original_name: 'provider_original_name',
        content: provider_json_content.to_json,
        serial_id: link_serial_id,
      )
    end
    let(:payload_json) do
      {
        'link_provider_id' => provider_id,
        'link_consumer' => {
          'owner_object' => {
            'name' => 'external_consumer_1',
            'type' => 'external',
          },
        },
      }
    end
    let(:provider_id) { provider_1_intent_1.id.to_s }

    describe '#create_link' do
      shared_examples 'creates consumer, consumer_intent and link' do
        it '#filter_content_and_create_link' do
          subject.create_link(payload_json)

          external_consumer = Bosh::Director::Models::Links::LinkConsumer.find(
            deployment: deployment,
            instance_group: '',
            name: 'external_consumer_1',
            type: 'external',
          )
          expect(external_consumer).to_not be_nil

          external_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
            link_consumer: external_consumer,
            original_name: provider_1_intent_1.original_name,
          )
          expect(external_consumer_intent).to_not be_nil
          expect(external_consumer_intent.name).to eq(provider_1_intent_1.name)
          expect(external_consumer_intent.type).to eq(provider_1_intent_1.type)

          external_link = Bosh::Director::Models::Links::Link.find(
            link_provider_intent_id: provider_1_intent_1.id,
            link_consumer_intent_id: external_consumer_intent.id,
            name: external_consumer_intent.original_name,
          )
          expect(external_link).to_not be_nil

          desired_address_from_payload = payload_json['network']
          default_instance_ip = provider_json_content[:instances][0][:addresses][provider_json_content[:default_network]&.to_sym]
          expected_instance_ip =
            provider_json_content[:instances][0][:addresses][desired_address_from_payload&.to_sym] || default_instance_ip

          expect(JSON.parse(external_link.link_content))
            .to match(
              'default_network' => String,
              'networks' => %w[neta netb],
              'instances' => [{ 'address' => expected_instance_ip }],
            )
        end
      end

      context 'when link_provider_id is invalid' do
        let(:provider_id) { '7654321' }
        it 'return error' do
          expect { subject.create_link(payload_json) }.to raise_error(
            Bosh::Director::LinkProviderLookupError,
            "Invalid link_provider_id: #{provider_id}",
          )
        end
      end

      context 'when link_provider_id is missing' do
        let(:provider_id) { '' }
        it 'return error' do
          expect { subject.create_link(payload_json) }.to raise_error(
            RuntimeError,
            /Invalid request: `link_provider_id` must be provided/,
          )
        end
      end

      context 'when provider_id (provider_intent_id) is valid' do
        it '#find_provider_intent' do
          expect(Bosh::Director::Models::Links::LinkProviderIntent).to receive(:find).and_return(provider_1_intent_1)

          subject.create_link(payload_json)
        end

        context 'when provider_id (provider_intent_id) is not shared' do
          let(:provider_1_intent_1) do
            Models::Links::LinkProviderIntent.create(
              name: 'link_name_1',
              link_provider: provider_1,
              shared: false,
              consumable: true,
              type: 'job',
              original_name: 'provider_name_1',
              content: provider_json_content.to_json,
              serial_id: link_serial_id,
            )
          end
          it 'return error' do
            expect { subject.create_link(payload_json) }.to raise_error(
              Bosh::Director::LinkProviderNotSharedError,
              'Provider not `shared`',
            )
          end
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
            expect { subject.create_link(payload_json) }.to raise_error(
              /Invalid request: `link_consumer` section must be defined/,
            )
          end
        end

        context 'when link_consumer contents are invalid' do
          context 'invalid owner_object structure' do
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
              expect { subject.create_link(payload_json) }.to raise_error(
                /Invalid request: `link_consumer.owner_object` section must be defined/,
              )
            end
          end

          context 'invalid owner_object.name' do
            let(:payload_json) do
              {
                'link_provider_id' => provider_id,
                'link_consumer' => {
                  'owner_object' => {
                    'name' => '',
                    'type' => 'external',
                  },
                },
              }
            end

            it 'return error' do
              expect { subject.create_link(payload_json) }.to raise_error(
                /Invalid request: `link_consumer.owner_object.name` must not be empty/,
              )
            end
          end

          context 'invalid owner_object.type' do
            let(:payload_json) do
              {
                'link_provider_id' => provider_id,
                'link_consumer' => {
                  'owner_object' => {
                    'name' => 'test_owner_name',
                    'type' => 'test_owner_type',
                  },
                },
              }
            end

            it 'return error' do
              expect { subject.create_link(payload_json) }.to raise_error(
                /Invalid request: `link_consumer.owner_object.type` should be 'external'/,
              )
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
                'owner_object' => {
                  'name' => 'external_consumer_1',
                  'type' => 'external',
                },
              },
              'network' => network_name,
            }
          end

          context 'when network is valid' do
            include_examples 'creates consumer, consumer_intent and link'
          end

          context 'when network is invalid' do
            let(:network_name) { 'invalid_network_name' }

            it 'return error' do
              expect { subject.create_link(payload_json) }.to raise_error(
                /Can't resolve network: `invalid_network_name` in provider id: #{provider_id} for `external_consumer_1`/,
              )
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
            expect { subject.delete_link(link_id) }.to raise_error(
              LinkNotExternalError,
              /Error deleting link: not a external link/,
            )
          end
        end

        context 'when link_id is non-existing' do
          let(:link_id) { 7654321 + not_external_link_1.id }
          it 'return error' do
            expect { subject.delete_link(link_id) }.to raise_error(
              LinkLookupError,
              "Invalid link id: #{link_id}",
            )
          end
        end
      end

      context 'when link id is valid' do
        context 'when link is external' do
          let(:deployment) do
            FactoryBot.create(:models_deployment)
          end

          let(:external_consumer) do
            Bosh::Director::Models::Links::LinkConsumer.create(
              deployment: deployment,
              instance_group: '',
              name: 'external_consumer_1',
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
                instance_group: '',
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
                subject.delete_link(external_link[:id])
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
                  subject.delete_link(external_link[:id])
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
                  subject.delete_link(external_link[:id])
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

    describe '#link_address' do
      context 'when the link does not exist' do
        it 'raises an error' do
          expect do
            subject.link_address('1')
          end.to raise_error(LinkLookupError, 'Could not find a link with id 1')
        end
      end

      context 'when the link exists' do
        let(:link_name) { 'control_consumer_link' }

        let(:link_content) do
          {
            'deployment_name' => 'dep_foo',
            'instance_group' => 'ig_bar',
            'default_network' => 'baz',
            'domain' => 'bosh',
            'use_short_dns_addresses' => false,
          }
        end

        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment,
            instance_group: '',
            name: 'consumer_1',
            type: 'job',
          )
        end

        let(:consumer_intent) do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'link_name',
            type: 'link_type',
          )
        end

        let!(:link) do
          Bosh::Director::Models::Links::Link.create(
            link_consumer_intent: consumer_intent,
            link_content: link_content.to_json,
            name: link_name,
          )
        end

        it 'should return the address of the link' do
          link_address = subject.link_address(link.id)
          expect(link_address).to eq('q-s0.ig-bar.baz.dep-foo.bosh')
        end

        context 'and an az parameter is specified' do
          let!(:az1) { Models::LocalDnsEncodedAz.create(name: 'z1') }
          let!(:az2) { Models::LocalDnsEncodedAz.create(name: 'z2') }

          it 'should return the address of the link' do
            link_address = subject.link_address(link.id, azs: ['z1'])
            expect(link_address).to eq("q-a#{az1.id}s0.ig-bar.baz.dep-foo.bosh")
          end
        end

        context 'and the status parameter is specified' do
          context 'and the status is "healthy"' do
            it 'should return the address of the link' do
              link_address = subject.link_address(link.id, status: 'healthy')
              expect(link_address).to eq('q-s3.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'and the status is "unhealthy"' do
            it 'should return the address of the link' do
              link_address = subject.link_address(link.id, status: 'unhealthy')
              expect(link_address).to eq('q-s1.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'and the status is "all"' do
            it 'should return the address of the link' do
              link_address = subject.link_address(link.id, status: 'all')
              expect(link_address).to eq('q-s4.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'and the status is "default"' do
            it 'should return the address of the link' do
              link_address = subject.link_address(link.id, status: 'default')
              expect(link_address).to eq('q-s0.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'and the status is invalid' do
            it 'should return the address of the link' do
              link_address = subject.link_address(link.id, status: 'foobar')
              expect(link_address).to eq('q-s0.ig-bar.baz.dep-foo.bosh')
            end
          end
        end

        context 'and the provider deployment is using short DNS' do
          before do
            Models::LocalDnsEncodedNetwork.create(name: 'bar')
            Models::LocalDnsEncodedNetwork.create(name: 'baz')
          end
          let!(:link) do
            Bosh::Director::Models::Links::Link.create(
              link_consumer_intent: consumer_intent,
              link_content: link_content.to_json,
              name: link_name,
            )
          end

          let(:link_content) do
            {
              'deployment_name' => 'test_deployment',
              'instance_group' => 'ig_bar',
              'default_network' => 'baz',
              'domain' => 'bosh',
              'use_short_dns_addresses' => true,
            }
          end

          it 'should return the short DNS address of the link' do
            group = Bosh::Director::Models::LocalDnsEncodedGroup.create(
              name: 'ig_bar',
              deployment_id: deployment.id,
              type: Bosh::Director::Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            )
            network = Bosh::Director::Models::LocalDnsEncodedNetwork.last

            link_address = subject.link_address(link.id)
            expect(link_address).to eq("q-n#{network.id}s0.q-g#{group.id}.bosh")
          end
        end

        context 'and the provider deployment is using link DNS names' do
          before do
            Models::LocalDnsEncodedNetwork.create(name: 'bar')
            Models::LocalDnsEncodedNetwork.create(name: 'baz')
          end

          let(:provider) do
            Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment,
              instance_group: instance_group,
              name: 'provider_name',
              type: 'job',
              serial_id: link_serial_id,
            )
          end

          let(:provider_intent) do
            Models::Links::LinkProviderIntent.create(
              name: 'link_name_1',
              link_provider: provider,
              shared: true,
              consumable: true,
              type: 'job',
              original_name: 'provider_original_name',
              content: provider_json_content.to_json,
              serial_id: link_serial_id,
            )
          end

          let!(:link) do
            Bosh::Director::Models::Links::Link.create(
              link_consumer_intent: consumer_intent,
              link_provider_intent: provider_intent,
              link_content: link_content.to_json,
              name: link_name,
            )
          end

          let(:link_content) do
            {
              'deployment_name' => 'test_deployment',
              'instance_group' => 'ig_bar',
              'group_name' => 'link_name_1-job',
              'default_network' => 'baz',
              'domain' => 'bosh',
              'use_short_dns_addresses' => true,
              'use_link_dns_names' => true,
            }
          end

          it 'should return the short DNS address of the link' do
            group = Bosh::Director::Models::LocalDnsEncodedGroup.create(
              name: 'link_name_1-job',
              deployment_id: deployment.id,
              type: Bosh::Director::Models::LocalDnsEncodedGroup::Types::LINK,
            )
            network = Bosh::Director::Models::LocalDnsEncodedNetwork.last

            link_address = subject.link_address(link.id)
            expect(link_address).to eq("q-n#{network.id}s0.q-g#{group.id}.bosh")
          end
        end

        context 'and the link is manual' do
          let(:provider) do
            Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment,
              instance_group: instance_group,
              name: 'manual_provider_name',
              type: 'manual',
              serial_id: link_serial_id,
            )
          end

          let(:provider_intent) do
            Models::Links::LinkProviderIntent.create(
              name: 'manual_link_name',
              link_provider: provider,
              shared: true,
              consumable: true,
              type: 'spaghetti',
              original_name: 'napolean',
              content: provider_json_content.to_json,
              serial_id: link_serial_id,
            )
          end

          let!(:link) do
            Bosh::Director::Models::Links::Link.create(
              link_provider_intent: provider_intent,
              link_consumer_intent: consumer_intent,
              link_content: link_content.to_json,
              name: link_name,
            )
          end

          let(:link_content) do
            {
              'address' => '192.168.1.254',
            }
          end

          it 'returns the address of the link' do
            link_address = subject.link_address(link.id)
            expect(link_address).to eq('192.168.1.254')
          end

          context 'when the address is not in the link content' do
            let(:link_content) do
              {
                'address' => nil,
              }
            end
            it 'should return a null address' do
              link_address = subject.link_address(link.id)
              expect(link_address).to be_nil
            end
          end
        end
      end
    end
  end
end
