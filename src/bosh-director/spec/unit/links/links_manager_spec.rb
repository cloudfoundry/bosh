require 'spec_helper'

describe Bosh::Director::Links::LinksManager do
  subject {Bosh::Director::Links::LinksManager.new(logger, event_logger, serial_id)}

  let(:logger) {Logging::Logger.new('TestLogger')}
  let(:event_logger) {Bosh::Director::EventLog::Log.new}

  let(:serial_id) { 42 }
  let(:event_manager) { Bosh::Director::Api::EventManager.new(true)}
  let(:task) {Bosh::Director::Models::Task.make(:username => 'user')}
  let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task.id, event_manager: event_manager)}
  let(:use_dns_addresses) { true }

  let(:deployment_model) do
    Bosh::Director::Models::Deployment.create(
      name: 'test_deployment',
      links_serial_id: serial_id
    )
  end

  before do
    allow(Bosh::Director::Config).to receive(:current_job).and_return(update_job)
  end

  describe '#find_or_create_provider' do
    it 'returns the existing provider' do
      expected_provider = Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        instance_group: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type',
        serial_id: serial_id,
      )

      actual_provider = subject.find_or_create_provider(
        deployment_model: deployment_model,
        instance_group_name: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type',
      )

      expect(actual_provider).to eq(expected_provider)
    end

    context 'link provider does not exist' do
      it 'creates a new provider' do
        expected_provider = subject.find_or_create_provider(
          deployment_model: deployment_model,
          instance_group_name: 'new_instance_group',
          name: 'new_owner_object_name',
          type: 'new_owner_object_type'
        )

        actual_provider = Bosh::Director::Models::Links::LinkProvider.find(
          deployment: deployment_model,
          instance_group: 'new_instance_group',
          name: 'new_owner_object_name',
          type: 'new_owner_object_type'
        )

        expect(actual_provider).to eq(expected_provider)
        expect(actual_provider.serial_id).to_not be_nil
      end
    end
  end

  describe '#find_provider' do
    context 'link provider exists' do
      let(:serial_id) { 55 }

      it 'returns the existing provider' do
        expected_provider = Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment_model,
          instance_group: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type',
          serial_id: serial_id,
        )

        actual_provider = subject.find_provider(
          deployment_model: deployment_model,
          instance_group_name: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type'
        )

        expect(actual_provider).to eq(expected_provider)
        expect(actual_provider.serial_id).to eq(serial_id)
      end
    end

    context 'link provider does not exist' do
      it 'does not return a provider' do
        actual_provider = subject.find_provider(
          deployment_model: deployment_model,
          instance_group_name: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type'
        )
        expect(actual_provider).to be_nil
      end
    end

    context 'when link provider with wrong serial_id exist' do
      let(:serial_id) { 55 }

      it 'returns nothing' do
        Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment_model,
          instance_group: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type',
          serial_id: 42,
          )

        actual_provider = subject.find_provider(
          deployment_model: deployment_model,
          instance_group_name: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type'
        )

        expect(actual_provider).to be_nil
      end
    end

  end

  describe '#find_or_create_provider_intent' do
    let(:link_provider) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group',
        serial_id: serial_id
      )
    end

    context 'intent already exists' do
      it 'returns the existing link_provider_intent' do
        expected_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          name: 'test_link_alias',
          content: 'test_link_content',
          shared: false,
          consumable: true,
          serial_id: serial_id
        )

        actual_intent = subject.find_or_create_provider_intent(
          link_provider: link_provider,
          link_original_name: "test_original_link_name",
          link_type: "test_link_type"
        )

        expect(actual_intent).to eq(expected_intent)
        expect(actual_intent.serial_id).to eq(serial_id)
      end

      it 'updates the link type of the intent' do
        expected_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          name: 'test_link_alias',
          content: 'test_link_content',
          shared: false,
          consumable: true,
          serial_id: serial_id
        )

        actual_intent = subject.find_or_create_provider_intent(
          link_provider: link_provider,
          link_original_name: "test_original_link_name",
          link_type: "my_new_link_type"
        )

        expect(actual_intent.id).to eq(expected_intent.id)
        expect(actual_intent.type).to eq('my_new_link_type')
      end
    end

    context 'intent is missing' do
      it 'creates a new link_provider_intent' do
        expect(Bosh::Director::Models::Links::LinkProviderIntent.count).to eq(0)

        actual_intent = subject.find_or_create_provider_intent(
          link_provider: link_provider,
          link_original_name: "test_original_link_name",
          link_type: "test_link_type"
        )

        expected_intent = Bosh::Director::Models::Links::LinkProviderIntent.find(
          link_provider: link_provider,
          original_name: "test_original_link_name",
          type: "test_link_type",
          shared: false,
          consumable: true
        )

        expect(Bosh::Director::Models::Links::LinkProviderIntent.count).to eq(1)
        expect(actual_intent).to eq(expected_intent)
        expect(actual_intent.serial_id).to eq(serial_id)
      end
    end
  end

  describe '#find_or_create_consumer' do
    let!(:control_consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        instance_group: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type',
        serial_id: serial_id
      )
    end

    it 'finds the consumer' do
      actual_consumer = subject.find_or_create_consumer(
        deployment_model: deployment_model,
        instance_group_name: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type'
      )

      expect(actual_consumer).to eq(control_consumer)
      expect(actual_consumer.serial_id).to eq(serial_id)
    end

    context 'consumer does not exist' do
      it 'creates a new consumer' do
        expected_consumer = subject.find_or_create_consumer(
          deployment_model: deployment_model,
          instance_group_name: 'my_instance_group',
          name: 'my_owner_object_name',
          type: 'my_owner_object_type'
        )

        actual_consumer = Bosh::Director::Models::Links::LinkConsumer.find(
          deployment: deployment_model,
          instance_group: 'my_instance_group',
          name: 'my_owner_object_name',
          type: 'my_owner_object_type'
        )

        expect(actual_consumer).to eq(expected_consumer)
        expect(actual_consumer.serial_id).to eq(serial_id)
      end
    end

  end

  describe '#find_or_create_consumer_intent' do
    let(:link_consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group',
        serial_id: serial_id
      )
    end

    context 'intent already exist' do
      it 'returns the existing link_consumer_intent' do
        expected_link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          optional: false,
          blocked: false,
          serial_id: serial_id
        )

        actual_link_consumer_intent = subject.find_or_create_consumer_intent(
          link_consumer: link_consumer,
          link_original_name: 'test_original_link_name',
          link_type: 'test_link_type',
          new_intent_metadata: nil,
        )

        expect(actual_link_consumer_intent).to eq(expected_link_consumer_intent)
        expect(actual_link_consumer_intent.serial_id).to eq(serial_id)
      end

      it 'updates the link type of the intent' do
        expected_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          optional: false,
          blocked: false,
          serial_id: serial_id
        )

        actual_intent = subject.find_or_create_consumer_intent(
          link_consumer: link_consumer,
          link_original_name: 'test_original_link_name',
          link_type: 'my_new_link_type',
          new_intent_metadata: nil,
        )

        expect(actual_intent.id).to eq(expected_intent.id)
        expect(actual_intent.type).to eq('my_new_link_type')
      end
    end

    context 'intent is missing' do
      it 'creates a new link_consumer_intent' do
        expected_intent = subject.find_or_create_consumer_intent(
          link_consumer: link_consumer,
          link_original_name: 'test_original_link_name',
          link_type: 'test_link_type',
          new_intent_metadata: {'abc':'def'}
        )

        actual_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
          link_consumer: link_consumer,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          optional: false,
          blocked: false
        )

        expect(actual_intent).to eq(expected_intent)
        expect(actual_intent.serial_id).to eq(serial_id)
        expect(actual_intent.metadata).to eq({'abc' => 'def'}.to_json)
      end
    end
  end

  describe '#find_consumer' do
    context 'link consumer exists' do
      it 'returns the existing consumer' do
        expected_consumer = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type',
          serial_id: serial_id
        )

        actual_consumer = subject.find_consumer(
          deployment_model: deployment_model,
          instance_group_name: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type'
        )
        expect(actual_consumer).to eq(expected_consumer)
        expect(actual_consumer.serial_id).to eq(serial_id)
      end
    end

    context 'link consumer does not exist' do
      it 'does not return a consumer' do
        actual_consumer = subject.find_consumer(
          deployment_model: deployment_model,
          instance_group_name: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'job'
        )
        expect(actual_consumer).to be_nil
      end
    end

    context 'when link consumer with wrong serial_id exists' do
      let(:serial_id) { 55 }
      it 'fails returns the existing consumer' do
        expected_consumer = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type',
          serial_id: 42
        )

        actual_consumer = subject.find_consumer(
          deployment_model: deployment_model,
          instance_group_name: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type'
        )
        expect(actual_consumer).to be_nil
      end
    end
  end

  describe '#find_link' do
    let(:provider) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        name: 'test_provider',
        type: 'job',
        instance_group: 'test_instance_group',
        serial_id: serial_id
      )
    end

    let(:provider_intent) do
      Bosh::Director::Models::Links::LinkProviderIntent.create(
        link_provider: provider,
        original_name: 'test_original_link_name',
        type: 'test_link_type',
        name: 'test_link_alias',
        content: '{}',
        shared: false,
        consumable: true,
        serial_id: serial_id
      )
    end

    let(:consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        name: 'test_consumer',
        type: 'job',
        instance_group: 'test_instance_group',
        serial_id: serial_id
      )
    end

    let(:consumer_intent) do
      Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: consumer,
        original_name: 'test_original_link_name',
        type: 'test_link_type',
        optional: false,
        blocked: false,
        serial_id: serial_id
      )
    end

    context 'link exists' do
      it 'returns the existing link' do
        expected_link = Bosh::Director::Models::Links::Link.create(
          link_provider_intent: provider_intent,
          link_consumer_intent: consumer_intent,
          name: 'test_original_link_name',
          link_content: '{}'
        )

        actual_link = subject.find_link(
          name: 'test_original_link_name',
          provider_intent: provider_intent,
          consumer_intent: consumer_intent
        )

        expect(actual_link).to eq(expected_link)
      end
    end

    context 'link does not exist' do
      it 'does not return a link' do
        actual_link = subject.find_link(
          name: 'test_original_link_name',
          provider_intent: provider_intent,
          consumer_intent: consumer_intent
        )
        expect(actual_link).to be_nil
      end
    end
  end

  describe '#find_or_create_link' do
    let(:link_provider) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group',
        serial_id: serial_id
      )
    end
    let(:link_consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group',
        serial_id: serial_id
      )
    end
    let(:provider_intent) do
      Bosh::Director::Models::Links::LinkProviderIntent.create(
        link_provider: link_provider,
        original_name: 'test_original_link_name',
        type: 'test_link_type',
        name: 'test_link_alias',
        content: 'test_link_content',
        shared: false,
        consumable: true,
        serial_id: serial_id
      )
    end
    let(:consumer_intent) do
      Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: link_consumer,
        original_name: 'test_original_link_name',
        type: 'test_link_type',
        optional: false,
        blocked: false,
        serial_id: serial_id
      )
    end


    context 'when link do not exist' do
      it 'creates a new link' do
        expected_link = subject.find_or_create_link(
          name: 'test_link_name',
          provider_intent: provider_intent,
          consumer_intent: consumer_intent,
          link_content: '{}'
        )

        actual_link = Bosh::Director::Models::Links::Link.find(
          name: 'test_link_name'
        )

        expect(actual_link).to eq(expected_link)
      end
    end

    context 'when link already exists' do
      let(:link_content_1) do
        {
          'deployment_name'=>'simple',
          'domain'=>'bosh',
          'default_network'=>'a',
          'networks'=> ['b', 'a'],
          'instance_group'=>'foobar',
          'properties'=>{
            'a'=>'default_a',
            'b'=>nil,
            'c'=>'default_c',
            'nested'=> {
              'one'=>'default_nested.one',
              'two'=>'default_nested.two',
              'three'=>nil,
            },
          },
          'instances'=>[
            {
              'name'=>'foobar',
              'id'=>'e836f635-cece-4531-a519-0bc857b190e8',
              'index'=>0,
              'bootstrap'=>true,
              'az'=>nil,
              'address'=>'192.168.1.2',
            }
          ]
        }
      end

      before do
        @expected_link_1 = subject.find_or_create_link(
          name: 'test_link_name',
          provider_intent: provider_intent,
          consumer_intent: consumer_intent,
          link_content: link_content_1.to_json
        )

        actual_link = Bosh::Director::Models::Links::Link.find(
          name: 'test_link_name'
        )
        expect(actual_link).to_not be_nil
      end

      context 'when content matches' do
        context 'when single link for provider anc consumer exists' do
          it 'should return existing link' do
            expected_link_2 = subject.find_or_create_link(
              name: 'test_link_name',
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: link_content_1.to_json,
            )

            expect(expected_link_2).to eq(@expected_link_1)
          end
        end

        context 'when multiple links for provider and consumer exist' do
          before do
            @expected_link_with_different_content = Bosh::Director::Models::Links::Link.create(
              name: "test_link_name_1",
              link_provider_intent_id: provider_intent[:id],
              link_consumer_intent_id: consumer_intent[:id],
              link_content: "{\"d\":\"e\", \"f\":\"g\"}",
            )

            actual_links = Bosh::Director::Models::Links::Link.where(
              link_provider_intent_id: provider_intent[:id],
              link_consumer_intent_id: consumer_intent[:id],
              )
            expect(actual_links).to_not be_nil
            expect(actual_links.count).to eq(2)
          end

          it 'should return correct link' do
            expected_link_2 = subject.find_or_create_link(
              name: "test_link_name_1",
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: "{\"d\":\"e\", \"f\":\"g\"}"
            )

            expect(expected_link_2).to eq(@expected_link_with_different_content)
            expect(expected_link_2[:link_content]).to eq(@expected_link_with_different_content[:link_content])
            expect(Bosh::Director::Models::Links::Link.all.count).to eq(2)
          end
        end
      end

      context 'when content hash elements are in different order' do
        context 'when properties are in different order' do
          before do
            link_content_1['properties']['nested'] = {
              'two'=>'default_nested.two',
              'one'=>'default_nested.one',
              'three'=>nil,
            }
          end

          it 'should return existing link' do
            expected_link_2 = subject.find_or_create_link(
              name: 'test_link_name',
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: link_content_1.to_json,
              )

            expect(expected_link_2[:id]).to eq(@expected_link_1[:id])
            expect(JSON.parse(expected_link_2[:link_content]).sort).to eq(JSON.parse(@expected_link_1[:link_content]).sort)
          end
        end

        context 'when networks are in different order' do
          before do
            link_content_1['networks'] = ['a', 'b']
          end

          it 'should return existing link' do
            expected_link_2 = subject.find_or_create_link(
              name: 'test_link_name',
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: link_content_1.to_json,
            )

            expect(expected_link_2[:id]).to eq(@expected_link_1[:id])
            expect(JSON.parse(expected_link_2[:link_content]).sort).to eq(JSON.parse(@expected_link_1[:link_content]).sort)
          end
        end
      end

      context 'when content does not match' do
        context 'when new network is added' do
          before do
            link_content_1['networks'] = ['a', 'b', 'c']
          end

          it 'should return new link' do
            expected_link_2 = subject.find_or_create_link(
              name: 'test_link_name',
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: link_content_1.to_json,
            )

            expect(expected_link_2[:id]).to_not eq(@expected_link_1[:id])
            expect(JSON.parse(expected_link_2[:link_content]).sort).to eq(link_content_1.sort)
          end
        end

        context 'when there is new default network' do
          before do
            link_content_1['default_network'] = 'b'
          end

          it 'should return new link' do
            expected_link_2 = subject.find_or_create_link(
              name: 'test_link_name',
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: link_content_1.to_json,
             )

            expect(expected_link_2[:id]).to_not eq(@expected_link_1[:id])
            expect(JSON.parse(expected_link_2[:link_content]).sort).to eq(link_content_1.sort)
          end
        end

        context 'when properties change' do
          before do
            link_content_1['properties']['nested'] = {
              'two'=>'default_nested.two.changed',
              'one'=>'default_nested.one.changed',
              'three'=>'new.default_nested.three',
            }
          end

          it 'should return new link' do
            expected_link_2 = subject.find_or_create_link(
              name: 'test_link_name',
              provider_intent: provider_intent,
              consumer_intent: consumer_intent,
              link_content: link_content_1.to_json
            )

            expect(expected_link_2[:id]).to_not eq(@expected_link_1[:id])
            expect(JSON.parse(expected_link_2[:link_content]).sort).to eq(link_content_1.sort)
          end
        end
      end
    end
  end

  describe '#resolve_deployment_links' do
    let(:global_use_dns_entry) {true}

    let(:options) do
      {
        :global_use_dns_entry => global_use_dns_entry,
        :dry_run => dry_run
      }
    end

    context 'when dry_run flag is true' do
      let(:dry_run) {true}

      context 'when it is an explicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'job',
            serial_id: serial_id
          )
        end

        let(:metadata) do
          {'explicit_link' => true}
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            name: 'provider_alias',
            type: 'foo',
            metadata: metadata.to_json,
            serial_id: serial_id
          )
        end

        context 'and the provider exists' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id
            )
          end

          it 'does not create a link' do
            expect(deployment_model.link_consumers.count).to be > 0
            subject.resolve_deployment_links(deployment_model, options)
            expect(Bosh::Director::Models::Links::Link.count).to eq(0)
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")
          end


          context 'when link consumer intent is optional' do
            before do
              link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
                link_consumer: consumer,
                original_name: 'ci1',
                type: 'foo'
              )

              link_consumer_intent.optional = true
              link_consumer_intent.save
            end

            it 'should raise an error' do
              expect(consumer.find_intent_by_name('ci1').optional).to eq(true)

              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")

              expect(Bosh::Director::Models::Links::Link.count).to eq(0)
            end
          end
        end

        context 'when provider serial_id do not match deployment links_serial_id' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job',
              serial_id: serial_id-1 #different serial id than deployment
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id-1 #different serial id than deployment
            )
            link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
              link_consumer: consumer,
              original_name: 'ci1',
              type: 'foo'
            )

            link_consumer_intent.optional = true
            link_consumer_intent.save
          end

          it 'should raise an error' do
            expect(consumer.find_intent_by_name('ci1').optional).to eq(true)

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")

            expect(Bosh::Director::Models::Links::Link.count).to eq(0)
          end
        end

        context 'and the providers are ambiguous' do
          let(:provider_intent_1_content) {nil}
          let(:provider_intent_2_content) {nil}

          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              content: provider_intent_1_content,
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias',
              type: 'foo',
              content: provider_intent_2_content,
              serial_id: serial_id
            )
          end

          it 'raises an error' do
            expect {
              expect(deployment_model.link_consumers.count).to be > 0
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of name/alias 'provider_alias' found for job 'c1' in instance group 'ig1'. All of these match:
   pi1 aliased as 'provider_alias' (job: p1, instance group: ig1)
   pi2 aliased as 'provider_alias' (job: p1, instance group: ig1)")
          end

          context 'when the providers are from different networks' do
            let(:provider_intent_1_content) do
              {networks: ['foo'], instances: []}.to_json
            end

            let(:provider_intent_2_content) do
              {networks: ['bar'], instances: []}.to_json
            end

            context 'and the consumer is requesting for a specific newtwork' do
              let(:metadata) do
                {
                  'explicit_link' => true,
                  'network' => 'bar'
                }
              end

              it 'should raise an error' do
                expect {
                  expect(deployment_model.link_consumers.count).to be > 0
                  subject.resolve_deployment_links(deployment_model, options)
                }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of name/alias 'provider_alias' found for job 'c1' in instance group 'ig1'. All of these match:
   pi1 aliased as 'provider_alias' (job: p1, instance group: ig1)
   pi2 aliased as 'provider_alias' (job: p1, instance group: ig1)")
              end
            end
          end

          context 'when link consumer intent is optional' do
            before do
              link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
                link_consumer: consumer,
                original_name: 'ci1',
                type: 'foo',
                )

              link_consumer_intent.optional = true
              link_consumer_intent.save
            end

            it 'raises an error' do
              expect(consumer.find_intent_by_name('ci1').optional).to eq(true)

              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of name/alias 'provider_alias' found for job 'c1' in instance group 'ig1'. All of these match:
   pi1 aliased as 'provider_alias' (job: p1, instance group: ig1)
   pi2 aliased as 'provider_alias' (job: p1, instance group: ig1)")

              expect(Bosh::Director::Models::Links::Link.count).to eq(0)
            end
          end
        end
      end

      context 'when it is an implicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'job',
            serial_id: serial_id
          )
        end

        let(:metadata) do
          {'explicit_link' => false}
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            type: 'foo',
            metadata: metadata.to_json,
            serial_id: serial_id
          )
        end

        context 'and the provider exists' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id
            )
          end

          it 'does not create a link' do
            expect(deployment_model.link_consumers.count).to be > 0
            subject.resolve_deployment_links(deployment_model, options)
            expect(Bosh::Director::Models::Links::Link.count).to eq(0)
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect {
              expect(deployment_model.link_consumers.count).to be > 0
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'ci1' with type 'foo' for job  'c1' in instance_group 'ig1' in deployment 'test_deployment'")
          end

          context 'when link consumer intent is optional' do
            before do
              link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
                link_consumer: consumer,
                original_name: 'ci1',
                type: 'foo'
              )

              link_consumer_intent.optional = true
              link_consumer_intent.save
            end

            it 'should NOT raise an error' do
              expect(consumer.find_intent_by_name('ci1').optional).to eq(true)

              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to_not raise_error

              expect(Bosh::Director::Models::Links::Link.count).to eq(0)
            end
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias2',
              type: 'foo',
              serial_id: serial_id
            )
          end

          it 'raises an error' do
            expect {
              expect(deployment_model.link_consumers.count).to be > 0
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of type 'foo' found for consumer link 'ci1' in job 'c1' in instance group 'ig1'. All of these match:
   Deployment: test_deployment, instance group: ig1, job: p1, link name/alias: provider_alias
   Deployment: test_deployment, instance group: ig1, job: p1, link name/alias: provider_alias2")
          end

          context 'when link consumer intent is optional' do
            before do
              link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
                link_consumer: consumer,
                original_name: 'ci1',
                type: 'foo'
              )

              link_consumer_intent.optional = true
              link_consumer_intent.save
            end

            it 'should raise an error' do
              expect(consumer.find_intent_by_name('ci1').optional).to eq(true)

              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of type 'foo' found for consumer link 'ci1' in job 'c1' in instance group 'ig1'. All of these match:
   Deployment: test_deployment, instance group: ig1, job: p1, link name/alias: provider_alias
   Deployment: test_deployment, instance group: ig1, job: p1, link name/alias: provider_alias2")

              expect(Bosh::Director::Models::Links::Link.count).to eq(0)
            end
          end
        end
      end

      context 'when it is a manual link' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'job',
            serial_id: serial_id
          )
        end

        let(:metadata) do
          {'explicit_link' => false}
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            type: 'foo',
            metadata: metadata.to_json,
            serial_id: serial_id
          )

          provider = Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'manual',
            serial_id: serial_id
          )

          Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: provider,
            original_name: 'ci1',
            type: 'foo',
            serial_id: serial_id
          )
        end

        it 'does not create a link' do
          expect(deployment_model.link_consumers.count).to be > 0
          subject.resolve_deployment_links(deployment_model, options)
          expect(Bosh::Director::Models::Links::Link.count).to eq(0)
        end
      end
    end

    context 'when dry_run flag is false' do
      let(:dry_run) {false}

      context 'when it is an explicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            name: 'c1',
            type: 'job',
            instance_group: 'ig1',
            serial_id: serial_id
          )
        end

        let(:metadata) do
          {
            'explicit_link' => true
          }
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            name: 'provider_alias',
            type: 'foo',
            metadata: metadata.to_json,
            serial_id: serial_id
          )
        end

        context 'and a provider exists' do
          let!(:provider) do
            Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )
          end

          context 'and the provider intent has matching "type" and "name"' do
            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi1',
                name: 'provider_alias',
                type: 'foo',
                content: {use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json,
                serial_id: serial_id
              )
            end

            it 'creates a link' do
              expect(deployment_model.link_consumers.count).to be > 0
              subject.resolve_deployment_links(deployment_model, options)
              expect(Bosh::Director::Models::Links::Link.count).to eq(1)
              expect(Bosh::Director::Models::Links::Link.first.link_content).to eq({use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{address: 'dns2'}]}.to_json)
            end
          end

          context 'and the provider intent has matching "type" but not "name"' do
            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi1',
                name: 'non-matching-alias',
                type: 'foo',
                content: {use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json,
                serial_id: serial_id
              )
            end

            it 'should raise an error' do
              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")
            end
          end
        end

        context 'and a provider does NOT exist' do
          it 'raises an error' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id
            )
          end

          it 'raises an error' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of name/alias 'provider_alias' found for job 'c1' in instance group 'ig1'. All of these match:
   pi1 aliased as 'provider_alias' (job: p1, instance group: ig1)
   pi2 aliased as 'provider_alias' (job: p1, instance group: ig1)")
          end
        end

        context 'and requesting provider from different deployment' do
          let!(:second_deployment_model) do
            Bosh::Director::Models::Deployment.create(
              name: 'second_deployment',
              links_serial_id: serial_id
            )
          end

          let(:metadata) do
            {
              'explicit_link' => true,
              'from_deployment' => 'second_deployment'
            }
          end

          context 'and the specified deployment has a matching shared provider intent' do
            before do
              provider = Bosh::Director::Models::Links::LinkProvider.create(
                deployment: second_deployment_model,
                name: 'p2',
                type: 'job',
                instance_group: 'ig2',
                serial_id: serial_id
              )

              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi2',
                name: 'provider_alias',
                type: 'foo',
                shared: true,
                content: {use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json,
                serial_id: serial_id
              )
            end

            it 'should create a link' do
              expect(deployment_model.link_consumers.count).to be > 0
              subject.resolve_deployment_links(deployment_model, options)
              expect(Bosh::Director::Models::Links::Link.count).to eq(1)
              expect(Bosh::Director::Models::Links::Link.first.link_content).to eq({use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{address: 'dns2'}]}.to_json)
            end

            context 'when use_dns_address is FALSE on provider' do
              let(:use_dns_addresses) {false}
              it 'should create a link' do
                expect(deployment_model.link_consumers.count).to be > 0
                subject.resolve_deployment_links(deployment_model, options)
                expect(Bosh::Director::Models::Links::Link.count).to eq(1)
                expect(Bosh::Director::Models::Links::Link.first.link_content).to eq({use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{address: 'ip2'}]}.to_json)
              end
            end
          end

          context 'and the specified deployment has a matching non-shared provider intent' do
            before do
              provider = Bosh::Director::Models::Links::LinkProvider.create(
                deployment: second_deployment_model,
                name: 'p2',
                type: 'job',
                instance_group: 'ig2',
                serial_id: serial_id
              )

              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi2',
                name: 'provider_alias',
                type: 'foo',
                shared: false,
                content: {use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json,
                serial_id: serial_id
              )
            end

            it 'should raise an error' do
              expect(deployment_model.link_consumers.count).to be > 0

              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")
            end
          end

          context 'and the specified deployment has no providers' do
            it 'should raise an error' do
              expect(deployment_model.link_consumers.count).to be > 0

              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' for job 'c1' in instance group 'ig1' in deployment 'test_deployment'")
            end
          end

          context 'and the specified deployment is not found' do
            let(:metadata) do
              {
                'explicit_link' => true,
                'from_deployment' => 'not_found_deployment'
              }
            end

            it 'raises an error' do
              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't find deployment 'not_found_deployment'")
            end
          end
        end

        context 'and requesting for ip addresses only' do
          let(:metadata) do
            {
              'explicit_link' => true,
              'ip_addresses' => true,
            }
          end

          let(:provider_intent_content) do
            {
              use_dns_addresses: use_dns_addresses,
              default_network: 'netb',
              networks: ['neta', 'netb'],
              instances: [
                {
                  dns_addresses: {neta: 'dns1', netb: 'dns2'},
                  addresses: {neta: 'ip1', netb: 'ip2'}
                }
              ]
            }
          end

          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              content: provider_intent_content.to_json,
              serial_id: serial_id
            )
          end

          it 'creates a link where "address" is an IP address' do
            expect(deployment_model.link_consumers.count).to be > 0

            expected_hash = {
              'use_dns_addresses' => use_dns_addresses,
              'default_network' => 'netb',
              'networks' => ['neta', 'netb'],
              'instances' => [{'address' => 'ip2'}]
            }

            subject.resolve_deployment_links(deployment_model, options)
            links = Bosh::Director::Models::Links::Link.all
            expect(links.size).to eq(1)
            expect(JSON.parse(links.first.link_content)).to eq(expected_hash)
          end

          context 'and "default_network" is not defined in the provider content' do
            let(:provider_intent_content) do
              {
                networks: ['neta', 'netb'],
                instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]
              }
            end

            it 'should raise an error' do
              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Unable to retrieve default network from provider. Please redeploy provider deployment")
            end
          end

          context 'and requesting a specific network' do
            let(:metadata) do
              {
                'explicit_link' => true,
                'ip_addresses' => true,
                'network' => 'neta'
              }
            end

            context 'and the provider intent has the requested network' do
              it 'creates a link where "address" is from the specified network' do
                expect(deployment_model.link_consumers.count).to be > 0
                expected_hash = {
                  'use_dns_addresses' => use_dns_addresses,
                  'default_network' => 'neta',
                  'networks' => ['neta', 'netb'],
                  'instances' => [{'address' => 'ip1'}]
                }
                subject.resolve_deployment_links(deployment_model, options)
                links = Bosh::Director::Models::Links::Link.all
                expect(links.size).to eq(1)
                expect(JSON.parse(links.first.link_content)).to eq(expected_hash)
              end

              context 'and an instance in the provider does not contain the preferred network' do
                let(:provider_intent_content) do
                  {
                    use_dns_addresses: use_dns_addresses,
                    default_network: 'netb',
                    networks: ['neta', 'netb'],
                    instances: [
                      {dns_addresses: {netb: 'dns2'}, addresses: {netb: 'ip2'}}
                    ]
                  }
                end

                it 'should raise an error' do
                  expect {
                    subject.resolve_deployment_links(deployment_model, options)
                  }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Provider link does not have network: 'neta'")
                end
              end
            end

            context 'and the provider intent does not have the requested network' do
              let(:provider_intent_content) do
                {
                  use_dns_addresses: use_dns_addresses,
                  default_network: 'netb',
                  networks: ['netb'],
                  instances: [
                    {
                      dns_addresses: {neta: 'dns1', netb: 'dns2'},
                      addresses: {neta: 'ip1', netb: 'ip2'}
                    }
                  ]
                }
              end

              it 'raises an error' do
                expect {
                  subject.resolve_deployment_links(deployment_model, options)
                }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' in instance group 'ig1' on job 'c1' in deployment 'test_deployment' with network 'neta'")
              end
            end
          end
        end

        context 'and requesting for DNS entries' do
          let(:metadata) do
            {
              'explicit_link' => true,
              'ip_addresses' => false,
            }
          end

          let(:provider_intent_content) do
            {
              use_dns_addresses: use_dns_addresses,
              default_network: 'netb',
              networks: ['neta', 'netb'],
              instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}
          end

          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              content: provider_intent_content.to_json,
              serial_id: serial_id
            )
          end

          it 'creates a link where "address" is a DNS entry' do
            expect(deployment_model.link_consumers.count).to be > 0
            subject.resolve_deployment_links(deployment_model, options)

            links = Bosh::Director::Models::Links::Link.all
            expect(links.size).to eq(1)
            expect(JSON.parse(links.first.link_content)).to eq({'use_dns_addresses' => use_dns_addresses, 'default_network' => 'netb', 'networks' => ['neta', 'netb'], 'instances' => [{'address' => 'dns2'}]})
          end

          context 'and "default_network" is not defined in the provider content' do
            let(:provider_intent_content) do
              {
                networks: ['neta', 'netb'],
                instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]
              }
            end

            it 'should raise an error' do
              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Unable to retrieve default network from provider. Please redeploy provider deployment")
            end
          end

          context 'and requesting a specific network' do
            let(:metadata) do
              {
                'explicit_link' => true,
                'ip_addresses' => false,
                'network' => 'neta'
              }
            end

            context 'and the provider intent has the requested network' do
              it 'creates a link where "address" is from the specified network' do
                expect(deployment_model.link_consumers.count).to be > 0

                expected_hash = {
                  'use_dns_addresses' => use_dns_addresses,
                  'default_network' => 'neta',
                  'networks' => ['neta', 'netb'],
                  'instances' => [{'address' => 'dns1'}]
                }
                subject.resolve_deployment_links(deployment_model, options)
                links = Bosh::Director::Models::Links::Link.all
                expect(links.size).to eq(1)
                expect(JSON.parse(links.first.link_content)).to eq(expected_hash)
              end

              context 'and an instance in the provider does not contain the preferred network' do
                let(:provider_intent_content) do
                  {
                    use_dns_addresses: use_dns_addresses,
                    default_network: 'netb',
                    networks: ['neta', 'netb'],
                    instances: [
                      {dns_addresses: {netb: 'dns2'}, addresses: {netb: 'ip2'}}
                    ]
                  }
                end

                it 'should raise an error' do
                  expect {
                    subject.resolve_deployment_links(deployment_model, options)
                  }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Provider link does not have network: 'neta'")
                end
              end
            end

            context 'and the provider intent does not have the requested network' do
              let(:provider_intent_content) do
                {
                  use_dns_addresses: use_dns_addresses,
                  default_network: 'netb',
                  networks: ['netb'],
                  instances: [
                    {
                      dns_addresses: {neta: 'dns1', netb: 'dns2'},
                      addresses: {neta: 'ip1', netb: 'ip2'}
                    }
                  ]
                }
              end

              it 'raises an error' do
                expect {
                  subject.resolve_deployment_links(deployment_model, options)
                }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' in instance group 'ig1' on job 'c1' in deployment 'test_deployment' with network 'neta'")
              end
            end
          end
        end

        context 'and ip_addresses is not defined in the consumer options in the manifest' do
          let(:metadata) do
            {
              'explicit_link' => true,
              'ip_addresses' => nil,
            }
          end
          let(:provider_intent_content) do
            {
              use_dns_addresses: use_dns_addresses,
              default_network: 'netb',
              instances: [
                {
                  dns_addresses: {neta: 'dns1', netb: 'dns2'},
                  addresses: {neta: 'ip1', netb: 'ip2'}
                }
              ]
            }
          end

          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              content: provider_intent_content.to_json,
              serial_id: serial_id
            )
          end

          context 'and the global_use_dns setting is TRUE' do
            let(:global_use_dns_entry) {true}

            it 'should honor the global setting' do
              subject.resolve_deployment_links(deployment_model, options)
              links = Bosh::Director::Models::Links::Link.all
              expect(links.size).to eq(1)
              expect(JSON.parse(links.first.link_content)).to eq({'use_dns_addresses' => use_dns_addresses, 'default_network' => 'netb', 'instances' => [{'address' => 'dns2'}]})
            end
          end

          context 'and the global_use_dns setting is FALSE (or consumer use_dns_addresses=false)' do
            context 'when provider intent has DNS enabled' do
              it 'creates a link with a DNS address' do
                expected_link_content_with_dns = {
                  'use_dns_addresses' => use_dns_addresses,
                  'default_network' => 'netb',
                  'instances' => [{'address' => 'dns2'}]
                }
                subject.resolve_deployment_links(deployment_model, options)
                links = Bosh::Director::Models::Links::Link.all
                expect(links.size).to eq(1)
                expect(JSON.parse(links.first.link_content)).to eq(expected_link_content_with_dns)
              end
            end

            context 'when provider intent has DNS disabled' do
              let(:use_dns_addresses) { false }
              let(:provider_intent_content) do
                {
                  use_dns_addresses: use_dns_addresses,
                  default_network: 'netb',
                  instances: [
                    {
                      dns_addresses: {neta: 'ip1', netb: 'ip2'},
                      addresses: {neta: 'ip1', netb: 'ip2'}
                    }]
                }
              end

              it 'creates a link with an IP address' do
                expected_link_content_with_dns = {
                  'use_dns_addresses' => use_dns_addresses,
                  'default_network' => 'netb',
                  'instances' => [{'address' => 'ip2'}]
                }
                subject.resolve_deployment_links(deployment_model, options)
                links = Bosh::Director::Models::Links::Link.all
                expect(links.size).to eq(1)
                expect(JSON.parse(links.first.link_content)).to eq(expected_link_content_with_dns)
              end
            end
          end
        end

        context 'and requesting a specific network' do
          let(:metadata) do
            {
              explicit_link: true,
              network: 'neta'
            }
          end

          let(:provider) do
            Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )
          end

          context 'and the provider intent has the requested network' do
            let(:link_provider_content) do
              {
                use_dns_addresses: use_dns_addresses,
                default_network: 'netb',
                networks: ['neta', 'netb'],
                instances: [
                  {dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}
                ]
              }
            end

            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi1',
                name: 'provider_alias',
                type: 'foo',
                content: link_provider_content.to_json,
                serial_id: serial_id
              )
            end

            it 'creates a link where "address" is from the specified network' do
              expect(deployment_model.link_consumers.count).to be > 0

              expected_link_content_with_dns = {
                'use_dns_addresses' => use_dns_addresses,
                'default_network' => 'neta',
                'networks' => ['neta', 'netb'],
                'instances' => [{'address' => 'dns1'}]
              }

              subject.resolve_deployment_links(deployment_model, options)
              links = Bosh::Director::Models::Links::Link.all
              expect(links.size).to eq(1)
              expect(JSON.parse(links.first.link_content)).to eq(expected_link_content_with_dns)
            end

            context 'and an instance in the provider does not contain the preferred network' do
              let(:link_provider_content) do
                {
                  networks: ['neta', 'netb'],
                  instances: [
                    {dns_addresses: {netb: 'dns2'}, addresses: {netb: 'ip2'}}
                  ]
                }
              end

              it 'should raise an error' do
                expect {
                  subject.resolve_deployment_links(deployment_model, options)
                }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Provider link does not have network: 'neta'")
              end
            end
          end

          context 'and the provider intent does not have the requested network' do
            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi1',
                name: 'provider_alias',
                type: 'foo',
                content: {
                  use_dns_addresses: use_dns_addresses,
                  default_network: 'netb',
                  networks: [],
                  instances: [
                    {dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}
                  ]}.to_json,
                serial_id: serial_id
              )
            end

            it 'raises an error' do
              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'provider_alias' in instance group 'ig1' on job 'c1' in deployment 'test_deployment' with network 'neta'")
            end
          end
        end
      end

      context 'when it is an implicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            name: 'c1',
            type: 'job',
            instance_group: 'ig1',
            serial_id: serial_id
          )
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            type: 'foo',
            metadata: {explicit_link: false}.to_json,
            serial_id: serial_id
          )
        end

        context 'and the provider exists' do
          let(:provider) do
            Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )
          end

          context 'and the provider intent has matching "type"' do
            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi1',
                name: 'provider_alias',
                type: 'foo',
                content: {use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json,
                serial_id: serial_id
              )
            end

            it 'creates a link' do
              expect(deployment_model.link_consumers.count).to be > 0

              subject.resolve_deployment_links(deployment_model, options)
              expect(Bosh::Director::Models::Links::Link.count).to eq(1)
              expect(Bosh::Director::Models::Links::Link.first.link_content).to eq({use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{address: 'dns2'}]}.to_json)
            end
          end

          context 'and the provider intent has non-matching "type"' do
            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'ci1',
                name: 'ci1',
                type: 'non-matching-type',
                content: {use_dns_addresses: use_dns_addresses, default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json,
                serial_id: serial_id
              )
            end

            it 'should raise an error' do
              expect {
                subject.resolve_deployment_links(deployment_model, options)
              }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'ci1' with type 'foo' for job  'c1' in instance_group 'ig1' in deployment 'test_deployment'")
            end
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Can't resolve link 'ci1' with type 'foo' for job  'c1' in instance_group 'ig1' in deployment 'test_deployment'")
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              serial_id: serial_id
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias2',
              type: 'foo',
              serial_id: serial_id
            )
          end

          it 'raises an error' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error("Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Multiple providers of type 'foo' found for consumer link 'ci1' in job 'c1' in instance group 'ig1'. All of these match:
   Deployment: test_deployment, instance group: ig1, job: p1, link name/alias: provider_alias
   Deployment: test_deployment, instance group: ig1, job: p1, link name/alias: provider_alias2")
          end
        end
      end

      context 'when it is a manual link' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'job',
            serial_id: serial_id
          )
        end

        let(:metadata) do
          {
            explicit_link: true,
            manual_link: true
          }
        end

        let(:manual_link_contents) do
          {
            :deployment_name => 'meow-deployment',
            :properties => {
              :port => 6
            },
            :instances => ['a', 'b']
          }
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            type: 'foo',
            metadata: metadata.to_json,
            serial_id: serial_id
          )
        end

        context 'when there is no manual link provider' do
          it 'should raise an error' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error "Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Failed to find manual link provider for consumer 'ci1' in job 'c1' in instance group 'ci1'"
          end
        end

        context 'when there is a manual link provider' do
          let!(:manual_link_provider) do
            Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'c1',
              type: 'manual',
              serial_id: serial_id
            )
          end

          it 'should raise an error when there is no satisfying provider intent' do
            expect(deployment_model.link_consumers.count).to be > 0

            expect {
              subject.resolve_deployment_links(deployment_model, options)
            }.to raise_error "Failed to resolve links from deployment 'test_deployment'. See errors below:\n  - Failed to find manual link provider for consumer 'ci1' in job 'c1' in instance group 'ci1'"
          end

          context 'when there is a manual link provider intent that satisfies the manual consumer' do
            before do
              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: manual_link_provider,
                original_name: 'ci1',
                type: 'foo',
                content: manual_link_contents.to_json,
                serial_id: serial_id
              )
            end

            it 'creates a link' do
              expect(deployment_model.link_consumers.count).to be > 0
              subject.resolve_deployment_links(deployment_model, options)

              links_created = Bosh::Director::Models::Links::Link.all

              expect(links_created.size).to eq(1)
              expect(links_created.first.link_content).to eq(manual_link_contents.to_json)
            end
          end
        end
      end
    end
  end

  describe '#bind_links_to_instance' do
    let(:instance_model) do
      Bosh::Director::Models::Instance.make(deployment: deployment_model)
    end

    let(:instance) do
      instance_double(Bosh::Director::DeploymentPlan::Instance).tap do |mock|
        allow(mock).to receive(:instance_group_name).and_return('instance-group-name')
        allow(mock).to receive(:deployment_model).and_return(deployment_model)
        allow(mock).to receive(:model).and_return(instance_model)
      end
    end

    context 'when an instance does not use links' do
      it 'should not create an association between any links to the instance' do
        subject.bind_links_to_instance(instance)

        expect(instance_model.links).to be_empty
      end
    end

    context 'when an instance uses links' do
      before do
        # Create consumer
        consumer = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'instance-group-name',
          name: 'job-1',
          type: 'job',
          serial_id: serial_id
        )

        consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer,
          original_name: 'foo',
          type: 'bar',
          name: 'foo-alias',
          serial_id: serial_id
        )

        @link = Bosh::Director::Models::Links::Link.create(
          link_consumer_intent: consumer_intent,
          name: 'foo',
          link_content: '{}'
        )
      end

      it 'should create an association between the instance and the links' do
        subject.bind_links_to_instance(instance)
        expect(instance_model.links.size).to eq(1)
      end

      it 'should updated intance_link with current serial_id' do
        subject.bind_links_to_instance(instance)
        expect(instance_model.links.size).to eq(1)
        instance_link = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id, link_id: @link.id)
        expect(instance_link.first.serial_id).to eq(serial_id)
      end

      context 'when consumer_intent serial_id do NOT match deployment links_serial_id' do
        before do
          # Create consumer
          consumer = Bosh::Director::Models::Links::LinkConsumer.find(
            deployment: deployment_model,
            instance_group: 'instance-group-name',
            name: 'job-1',
            type: 'job',
            serial_id: serial_id
          )

          consumer_intent_2 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'foo2',
            type: 'bar2',
            name: 'foo-alias2',
            serial_id: serial_id - 1 # different from current deployment links_serial_id
          )

          @link2 = Bosh::Director::Models::Links::Link.create(
            link_consumer_intent: consumer_intent_2,
            name: 'foo',
            link_content: '{}'
          )

          instance_model.add_link(@link2)
          instance_link = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id, link_id: @link2.id).first
          instance_link.serial_id = serial_id - 1 # different from current deployment links_serial_id
          instance_link.save
        end

        it 'should not update links which do NOT match links_serial_id' do
          subject.bind_links_to_instance(instance)
          expect(instance_model.links.size).to eq(2)

          instance_link = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id, link_id: @link2.id)
          expect(instance_link.first.serial_id).to eq(serial_id - 1 )
        end
      end
    end
  end

  describe '#get_links_for_instance_group' do
    let(:instance_group_name) {'instance-group-name'}

    context 'when an instance does not use links' do
      it 'returns an empty hash' do
        links = subject.get_links_for_instance_group(deployment_model, instance_group_name)

        expect(links).to be_empty
      end
    end

    context 'when an instance uses links' do
      before do
        # Create consumer
        control_consumer = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'control-instance-group-name',
          name: 'control-job-1',
          type: 'job',
          serial_id: serial_id
        )

        control_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: control_consumer,
          original_name: 'control-foo',
          type: 'control-bar',
          name: 'control-foo-alias',
          serial_id: serial_id
        )

        Bosh::Director::Models::Links::Link.create(
          link_consumer_intent: control_consumer_intent,
          name: 'control-foo',
          link_content: '{}',
        )

        consumer = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'instance-group-name',
          name: 'job-1',
          type: 'job',
          serial_id: serial_id
        )

        consumer_intent_1 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer,
          original_name: 'foo',
          type: 'bar',
          name: 'foo-alias',
          serial_id: serial_id
        )

        Bosh::Director::Models::Links::Link.create(
          link_consumer_intent: consumer_intent_1,
          name: 'foo',
          link_content: '{"properties": {"fizz": "buzz"}}'
        )

        consumer_intent_2 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer,
          original_name: 'meow',
          type: 'bar',
          name: 'meow-alias',
          serial_id: serial_id
        )

        Bosh::Director::Models::Links::Link.create(
          link_consumer_intent: consumer_intent_2,
          name: 'meow',
          link_content: '{"properties": {"snoopy": "dog"}}'
        )
      end

      it 'should return the links associated with the instance groups namespaced by job name' do
        links = subject.get_links_for_instance_group(deployment_model, instance_group_name)
        expect(links.size).to eq(1)
        expect(links['job-1'].size).to eq(2)

        expect(links['job-1']['foo']).to eq({'properties' => {'fizz' => 'buzz'}})
        expect(links['job-1']['meow']).to eq({'properties' => {'snoopy' => 'dog'}})
      end

      context 'when consumer_intent serial_id do NOT match with consumer serial_id' do
        before do
          consumer = Bosh::Director::Models::Links::LinkConsumer.find(
            deployment: deployment_model,
            instance_group: 'instance-group-name',
            name: 'job-1',
            type: 'job',
          )

          consumer_intent_2a = Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'foo2',
            type: 'bar2',
            name: 'foo-alias2',
            serial_id: serial_id - 1 #different serial id than consumer
          )

          Bosh::Director::Models::Links::Link.create(
            link_consumer_intent: consumer_intent_2a,
            name: 'tweet',
            link_content: '{"properties": {"puddy": "tat"}}'
          )
        end

        it 'should return the links associated with the instance groups namespaced by job name' do
          links = subject.get_links_for_instance_group(deployment_model, instance_group_name)
          expect(links.size).to eq(1)
          expect(links['job-1'].size).to eq(2)

          expect(links['job-1']['foo']).to eq({'properties' => {'fizz' => 'buzz'}})
          expect(links['job-1']['meow']).to eq({'properties' => {'snoopy' => 'dog'}})
        end
      end
    end
  end

  describe '#get_links_from_deployment' do
    before do
      consumer = Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        instance_group: 'ig1',
        name: 'c1',
        type: 'job',
        serial_id: serial_id
      )

      consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: consumer,
        original_name: 'ci1',
        type: 'foo',
        metadata: {explicit_link: true}.to_json,
        serial_id: serial_id
      )

      provider = Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        instance_group: 'ig1',
        name: 'c1',
        type: 'manual',
        serial_id: serial_id
      )

      provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
        link_provider: provider,
        original_name: 'ci1',
        type: 'foo',
        serial_id: serial_id
      )

      Bosh::Director::Models::Links::Link.create(
        link_provider_intent: provider_intent,
        link_consumer_intent: consumer_intent,
        name: consumer_intent.original_name,
        link_content: '{"foo": "bar"}'
      )
    end

    it 'should return a JSON string with the links encoded within it.' do
      result = subject.get_links_from_deployment(deployment_model)
      expected_result = {
        "c1" => {
          "ci1" => {
            "foo" => "bar"
          }
        }
      }
      expect(result).to match(expected_result)
    end
  end

  describe '#update_provider_intents_contents' do
    let(:deployment_model) {BD::Models::Deployment.make(links_serial_id: serial_id)}
    let(:link_providers) {[]}
    let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner)}

    context 'when the provider type is a job' do
      let(:provider_1) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'foo-ig',
          name: 'foo-provider',
          type: 'job',
          serial_id: serial_id
        )
      end

      let(:provider_1_intent_1) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_1,
          :original_name => 'link_original_name_1',
          :name => 'link_name_1',
          :type => 'link_type_1',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'a' => '1'}}.to_json,
          :serial_id => serial_id
        )
      end

      let(:provider_1_intent_2) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_1,
          :original_name => 'link_original_name_2',
          :name => 'link_name_2',
          :type => 'link_type_2',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'b' => '2'}}.to_json,
          :serial_id => serial_id
        )
      end

      let(:provider_2) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'foo-ig',
          name: 'foo-provider-2',
          type: 'job',
          serial_id: serial_id
        )
      end

      let(:provider_2_intent_1) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_2,
          :original_name => 'link_original_name_3',
          :name => 'link_name_3',
          :type => 'link_type_3',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'c' => '1'}}.to_json,
          :serial_id => serial_id
        )
      end

      let(:provider_2_intent_2) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_2,
          :original_name => 'link_original_name_4',
          :name => 'link_name_4',
          :type => 'link_type_4',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'d' => '2'}}.to_json,
          :serial_id => serial_id
        )
      end
      let(:provider_2_intent_3) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_2,
          :original_name => 'link_original_name_5',
          :name => 'link_name_5',
          :type => 'link_type_5',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'e' => '5'}}.to_json,
          :serial_id => serial_id - 1 # different from current deployment links_serial_id
        )
      end
      let(:link_providers) do
        [provider_1, provider_2]
      end

      let(:instance_group) do
        instance_double(Bosh::Director::DeploymentPlan::InstanceGroup)
      end

      let(:link_1) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_2) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_3) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_4) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_5) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:use_short_dns_addresses) { false }
      let(:use_dns_addresses) { false }

      before do
         allow(provider_1).to receive(:intents).and_return([provider_1_intent_1, provider_1_intent_2])
         allow(provider_2).to receive(:intents).and_return([provider_2_intent_1, provider_2_intent_2])
         allow(deployment_model).to receive(:link_providers).and_return(link_providers)

         allow(link_1).to receive_message_chain(:spec, :to_json).and_return("{'foo_1':'bar_1'}")
         allow(link_2).to receive_message_chain(:spec, :to_json).and_return("{'foo_2':'bar_2'}")
         allow(link_3).to receive_message_chain(:spec, :to_json).and_return("{'foo_3':'bar_3'}")
         allow(link_4).to receive_message_chain(:spec, :to_json).and_return("{'foo_4':'bar_4'}")
         allow(link_5).to receive_message_chain(:spec, :to_json).and_return("{'foo_5':'bar_5'}")
         allow(deployment_plan).to receive(:instance_group).and_return(instance_group)
         allow(deployment_plan).to receive(:model).and_return(deployment_model)
         allow(deployment_plan).to receive(:use_short_dns_addresses?).and_return(use_short_dns_addresses)
         allow(deployment_plan).to receive(:use_dns_addresses?).and_return(use_dns_addresses)
       end

      context 'and use_short_dns_addresses is enabled' do
        let(:use_short_dns_addresses) { true }
        let(:use_dns_addresses) { true }

        it 'updates the contents field of the provider intents' do
          expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'a' => '1' }, use_dns_addresses, use_short_dns_addresses).and_return(link_1)
          expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'b' => '2' }, use_dns_addresses, use_short_dns_addresses).and_return(link_2)
          expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'c' => '1' }, use_dns_addresses, use_short_dns_addresses).and_return(link_3)
          expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'd' => '2' }, use_dns_addresses, use_short_dns_addresses).and_return(link_4)

          expect(provider_1_intent_1).to receive(:save)
          expect(provider_1_intent_2).to receive(:save)
          expect(provider_2_intent_1).to receive(:save)
          expect(provider_2_intent_2).to receive(:save)

          subject.update_provider_intents_contents(link_providers, deployment_plan)

          expect(provider_1_intent_1.content).to eq("{'foo_1':'bar_1'}")
          expect(provider_1_intent_2.content).to eq("{'foo_2':'bar_2'}")
          expect(provider_2_intent_1.content).to eq("{'foo_3':'bar_3'}")
          expect(provider_2_intent_2.content).to eq("{'foo_4':'bar_4'}")
        end
      end

      it 'updates the contents field of the provider intents' do
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'b' => '2' }, use_dns_addresses, use_short_dns_addresses).and_return(link_2)
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'a' => '1' }, use_dns_addresses, use_short_dns_addresses).and_return(link_1)
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'c' => '1' }, use_dns_addresses, use_short_dns_addresses).and_return(link_3)
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'd' => '2' }, use_dns_addresses, use_short_dns_addresses).and_return(link_4)

        expect(provider_1_intent_1).to receive(:save)
        expect(provider_1_intent_2).to receive(:save)
        expect(provider_2_intent_1).to receive(:save)
        expect(provider_2_intent_2).to receive(:save)

        subject.update_provider_intents_contents(link_providers, deployment_plan)

        expect(provider_1_intent_1.content).to eq("{'foo_1':'bar_1'}")
        expect(provider_1_intent_2.content).to eq("{'foo_2':'bar_2'}")
        expect(provider_2_intent_1.content).to eq("{'foo_3':'bar_3'}")
        expect(provider_2_intent_2.content).to eq("{'foo_4':'bar_4'}")
      end

      it 'should only update contents of provider_intents with matching provider serial_id' do
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'a' => '1' }, false, false).and_return(link_1)
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'b' => '2' }, false, false).and_return(link_2)
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'c' => '1' }, false, false).and_return(link_3)
        expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with(deployment_model.name, instance_group, { 'd' => '2' }, false, false).and_return(link_4)
        expect(Bosh::Director::DeploymentPlan::Link).to_not receive(:new).with(deployment_model.name, instance_group, { 'e' => '5' }, false, false)

        expect(provider_2_intent_3).to_not receive(:save)
        allow(provider_2).to receive(:intents).and_return([provider_2_intent_1, provider_2_intent_2, provider_2_intent_3])

        subject.update_provider_intents_contents(link_providers, deployment_plan)
        expect(provider_1_intent_1.content).to eq("{'foo_1':'bar_1'}")
        expect(provider_1_intent_2.content).to eq("{'foo_2':'bar_2'}")
        expect(provider_2_intent_1.content).to eq("{'foo_3':'bar_3'}")
        expect(provider_2_intent_2.content).to eq("{'foo_4':'bar_4'}")
        expect(provider_2_intent_3.content).to eq("{}")
      end
    end

    shared_examples_for 'non-job providers' do
      before do
        allow(provider).to receive(:intents).and_return([provider_intent])
        allow(deployment_model).to receive(:link_providers).and_return(link_providers)
        allow(deployment_plan).to receive(:model).and_return(deployment_model)
      end

      let(:provider) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'ig',
          name: 'some-provider',
          type: provider_type
        )
      end

      let(:provider_intent) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider,
          :original_name => 'link_original_name_1',
          :name => 'link_name_1',
          :type => 'link_type_1',
          :shared => true,
          :consumable => true,
          :content => 'some link content'
        )
      end

      let(:link_providers) do
        [provider]
      end

      it 'does not modify the contents field of the provider intents' do
        expect(provider_intent).to_not receive(:save)

        subject.update_provider_intents_contents(link_providers, deployment_plan)
        expect(provider_intent.content).to eq('some link content')
      end
    end

    context 'when the provider type is manual' do
      let(:provider_type) {'manual'}

      it_behaves_like 'non-job providers'
    end

    context 'when the provider type is disk' do
      let(:provider_type) {'disk'}

      it_behaves_like 'non-job providers'
    end

    context 'when the provider type is somthing else' do
      let(:provider_type) {'meow'}

      it_behaves_like 'non-job providers'
    end
  end

  describe '#remove_unused_links' do
    let(:deployment_model) {BD::Models::Deployment.make(links_serial_id: serial_id)}
    let(:link_providers) {[]}
    let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner)}
    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment_model) }

    context 'cleanup providers' do
      let(:provider_1) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'foo-ig',
          name: 'foo-provider',
          type: 'job',
          serial_id: serial_id - 1
        )
      end

      let(:provider_1_intent_1) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_1,
          :original_name => 'link_original_name_1',
          :name => 'link_name_1',
          :type => 'link_type_1',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'a' => '1'}}.to_json,
          :serial_id => serial_id - 1
        )
      end
      let(:provider_1_intent_2) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_1,
          :original_name => 'link_original_name_2',
          :name => 'link_name_2',
          :type => 'link_type_2',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'b' => '2'}}.to_json,
          :serial_id => serial_id - 1
        )
      end

      let(:provider_2) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'foo-ig',
          name: 'foo-provider-2',
          type: 'job',
          serial_id: serial_id
        )
      end

      let(:provider_2_intent_1) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_2,
          :original_name => 'link_original_name_3',
          :name => 'link_name_3',
          :type => 'link_type_3',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'c' => '1'}}.to_json,
          :serial_id => serial_id
        )
      end
      let(:provider_2_intent_2) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_2,
          :original_name => 'link_original_name_4',
          :name => 'link_name_4',
          :type => 'link_type_4',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'d' => '2'}}.to_json,
          :serial_id => serial_id
        )
      end
      let(:provider_2_intent_3) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_2,
          :original_name => 'link_original_name_5',
          :name => 'link_name_5',
          :type => 'link_type_5',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :metadata => {'mapped_properties' => {'e' => '5'}}.to_json,
          :serial_id => serial_id - 1 # different from current deployment links_serial_id
        )
      end

      let(:link_providers) do
        [provider_1, provider_2]
      end

      let(:instance_group) do
        instance_double(Bosh::Director::DeploymentPlan::InstanceGroup)
      end

      let(:link_1) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_2) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_3) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_4) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      let(:link_5) do
        instance_double(Bosh::Director::DeploymentPlan::Link)
      end

      before do
        allow(provider_1).to receive(:intents).and_return([provider_1_intent_1, provider_1_intent_2])
        allow(provider_2).to receive(:intents).and_return([provider_2_intent_1, provider_2_intent_2])
        allow(deployment_model).to receive(:link_providers).and_return(link_providers)

        allow(link_1).to receive_message_chain(:spec, :to_json).and_return("{'foo_1':'bar_1'}")
        allow(link_2).to receive_message_chain(:spec, :to_json).and_return("{'foo_2':'bar_2'}")
        allow(link_3).to receive_message_chain(:spec, :to_json).and_return("{'foo_3':'bar_3'}")
        allow(link_4).to receive_message_chain(:spec, :to_json).and_return("{'foo_4':'bar_4'}")
        allow(link_5).to receive_message_chain(:spec, :to_json).and_return("{'foo_5':'bar_5'}")
        allow(deployment_plan).to receive(:instance_group).and_return(instance_group)
        allow(deployment_plan).to receive(:model).and_return(deployment_model)
      end

      it 'removes job providers with old serial_ids' do
        subject.remove_unused_links(deployment_model)
        providers = Bosh::Director::Models::Links::LinkProvider.where(deployment: deployment_model)
        expect(providers.count).to eq(1)
        expect(providers.first.serial_id).to eq(serial_id)
      end

      it 'removes job provider_intents with old serial_ids' do
        subject.remove_unused_links(deployment_model)
        providers = Bosh::Director::Models::Links::LinkProvider.where(deployment: deployment_model)
        expect(providers.count).to eq(1)
        expect(providers.first.intents.count).to eq(2)
      end

      #TODO LINKS: add it later
      xit 'removes unused disk providers' do
        subject.remove_unused_links(deployment_model)
      end
    end

    context 'cleanup consumers' do
      before do
        consumer_1 = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'ig1',
          name: 'c1',
          type: 'job',
          serial_id: serial_id - 1
        )

        consumer_1_intent_1 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_1,
          original_name: 'ci1-1',
          type: 'foo',
          metadata: {explicit_link: true}.to_json,
          serial_id: serial_id - 1 # different from current deployment links_serial_id
        )
        consumer_1_intent_2 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_1,
          original_name: 'ci1-2',
          type: 'foo',
          metadata: {explicit_link: true}.to_json,
          serial_id: serial_id - 1 # different from current deployment links_serial_id
        )

        consumer_2 = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'ig1',
          name: 'c1-2',
          type: 'job',
          serial_id: serial_id
        )

        consumer_2_intent_1 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_2,
          original_name: 'ci2-1',
          type: 'foo',
          metadata: {explicit_link: true}.to_json,
          serial_id: serial_id
        )
        consumer_2_intent_2 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_2,
          original_name: 'ci2-2',
          type: 'foo',
          metadata: {explicit_link: true}.to_json,
          serial_id: serial_id - 1 # different from current deployment links_serial_id
        )
      end
      it 'removes consumers with old serial_ids' do
        subject.remove_unused_links(deployment_model)
        consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: deployment_model)
        expect(consumers.count).to eq(1)
        expect(consumers.first.serial_id).to eq(serial_id)

      end

      it 'removes consumer_intents with old serial_ids' do
        subject.remove_unused_links(deployment_model)
        consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: deployment_model)
        expect(consumers.count).to eq(1)
        expect(consumers.first.intents.count).to eq(1)
      end
    end

    context 'cleanup links' do
      before do
        consumer_1 = Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment_model,
          instance_group: 'ig1',
          name: 'c1',
          type: 'job',
          serial_id: serial_id
        )

        consumer_1_intent_1 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_1,
          original_name: 'ci1-1',
          type: 'foo',
          metadata: {explicit_link: true}.to_json,
          serial_id: serial_id
        )
        consumer_1_intent_2 = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_1,
          original_name: 'ci1-2',
          type: 'foo',
          metadata: {explicit_link: true}.to_json,
          serial_id: serial_id
        )

        provider = Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment_model,
          instance_group: 'ig1',
          name: 'c1',
          type: 'manual',
          serial_id: serial_id - 1
        )

        provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: provider,
          original_name: 'ci1',
          type: 'foo',
          content: '{}',
          serial_id: serial_id - 1
        )

        link_1 = Bosh::Director::Models::Links::Link.create(
          link_provider_intent: provider_intent,
          link_consumer_intent: consumer_1_intent_1,
          name: consumer_1_intent_1.original_name,
          link_content: '{}'
        )

        instance_model.add_link(link_1)
        instance_link = Bosh::Director::Models::Links::InstancesLink.where(link_id: link_1.id).first
        instance_link.serial_id = serial_id - 1
        instance_link.save

        provider_2 = Bosh::Director::Models::Links::LinkProvider.find_or_create(
          deployment: deployment_model,
          instance_group: 'ig1',
          name: 'c1',
          type: 'manual',
        )
        provider_2.serial_id = serial_id
        provider_2.save

        provider_2_intent_1 = Bosh::Director::Models::Links::LinkProviderIntent.find_or_create(
          link_provider: provider_2,
          original_name: 'ci1',
          type: 'foo',
        )
        provider_2_intent_1.content = '{"foo": "bar"}'
        provider_2_intent_1.serial_id = serial_id
        provider_2_intent_1.save

        link_2 = Bosh::Director::Models::Links::Link.create(
          link_provider_intent: provider_intent,
          link_consumer_intent: consumer_1_intent_1,
          name: consumer_1_intent_1.original_name,
          link_content: '{"foo": "bar"}'
        )

        instance_model.add_link(link_2)
        instance_link = Bosh::Director::Models::Links::InstancesLink.where(link_id: link_2.id).first
        instance_link.serial_id = serial_id
        instance_link.save
      end

      it 'removes links with instances_link with old serial_ids' do
        subject.remove_unused_links(deployment_model)
        links = Bosh::Director::Models::Links::Link.all
        expect(links.first.link_content).to eq('{"foo": "bar"}')
      end

      it 'removes instances_links with old serial_ids' do
        subject.remove_unused_links(deployment_model)
        expect(Bosh::Director::Models::Links::InstancesLink.count).to eq(1)
      end

    end
  end
end
