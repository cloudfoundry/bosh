require 'spec_helper'

describe Bosh::Director::Links::LinksManager do
  subject {Bosh::Director::Links::LinksManager.new}

  let(:deployment_model) do
    Bosh::Director::Models::Deployment.create(
      name: 'test_deployment'
    )
  end

  describe '#find_or_create_provider' do
    let!(:expected_provider) {}

    it 'returns the existing provider' do
      expected_provider = Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        instance_group: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type'
      )

      actual_provider = subject.find_or_create_provider(
        deployment_model: deployment_model,
        instance_group_name: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type'
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
      end
    end
  end

  describe '#find_provider' do
    context 'link provider exists' do
      it 'returns the existing provider' do
        expected_provider = Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment_model,
          instance_group: 'control_instance_group',
          name: 'control_owner_object_name',
          type: 'control_owner_object_type'
        )

        actual_provider = subject.find_provider(
          deployment_model: deployment_model,
          instance_group_name: "control_instance_group",
          name: "control_owner_object_name"
        )
        expect(actual_provider).to eq(expected_provider)
      end
    end

    context 'link provider does not exist' do
      it 'does not return a provider' do
        actual_provider = subject.find_provider(
          deployment_model: deployment_model,
          instance_group_name: "control_instance_group",
          name: "control_owner_object_name"
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
        instance_group: 'test_instance_group'
      )
    end

    context 'intent already exist' do
      it 'returns the existing link_provider_intent' do
        expected_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          name: 'test_link_alias',
          content: 'test_link_content',
          shared: false,
          consumable: true
        )

        actual_intent = subject.find_or_create_provider_intent(
          link_provider: link_provider,
          link_name: "test_original_link_name",
          link_type: "test_link_type",
        )

        expect(actual_intent).to eq(expected_intent)
      end
    end

    context 'intent is missing' do
      it 'creates a new link_provider_intent' do
        expect(Bosh::Director::Models::Links::LinkProviderIntent.count).to eq(0)

        provided_intent = subject.find_or_create_provider_intent(
          link_provider: link_provider,
          link_name: "test_original_link_name",
          link_type: "test_link_type",
        )

        expect(Bosh::Director::Models::Links::LinkProviderIntent.count).to eq(1)
        saved_provided_intent = Bosh::Director::Models::Links::LinkProviderIntent.find(
          link_provider: link_provider,
          original_name: "test_original_link_name",
          type: "test_link_type",
          shared: false,
          consumable: true
        )

        expect(provided_intent).to eq(saved_provided_intent)
      end
    end
  end

  describe '#find_provider_intent' do
    let(:link_provider) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group'
      )
    end

    context 'when searching by alias' do
      context 'intent already exist' do

        it 'returns the existing link_provider_intent' do
          expected_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: link_provider,
            original_name: 'test_original_link_name',
            type: 'test_link_type',
            name: 'test_link_alias',
            content: 'test_link_content',
            shared: false,
            consumable: true
          )

          actual_intent = subject.find_provider_intent(
            link_provider: link_provider,
            link_name: nil,
            link_alias: 'test_link_alias',
            link_type: "test_link_type"
          )

          expect(actual_intent).to eq(expected_intent)
        end
      end

      context 'intent is missing' do
        it 'does not return a link_provider_intent' do
          actual_intent = subject.find_provider_intent(
            link_provider: link_provider,
            link_name: nil,
            link_alias: "test_link_alias",
            link_type: "test_link_type"
          )

          expect(actual_intent).to be_nil
        end
      end
    end

    context 'when searching by name' do
      context 'intent already exist' do

        it 'returns the existing link_provider_intent' do
          expected_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: link_provider,
            original_name: 'test_original_link_name',
            type: 'test_link_type',
            name: 'test_link_alias',
            content: 'test_link_content',
            shared: false,
            consumable: true
          )

          actual_intent = subject.find_provider_intent(
            link_provider: link_provider,
            link_name: "test_original_link_name",
            link_alias: nil,
            link_type: "test_link_type"
          )

          expect(actual_intent).to eq(expected_intent)
        end
      end

      context 'intent is missing' do
        it 'does not return a link_provider_intent' do
          actual_intent = subject.find_provider_intent(
            link_provider: link_provider,
            link_name: "test_original_link_name",
            link_alias: nil,
            link_type: "test_link_type"
          )

          expect(actual_intent).to be_nil
        end
      end
    end


  end

  describe '#find_or_create_consumer' do
    let!(:control_consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        instance_group: 'control_instance_group',
        name: 'control_owner_object_name',
        type: 'control_owner_object_type'
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
      end
    end

  end

  describe '#find_or_create_consumer_intent' do
    let(:link_consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group'
      )
    end

    context 'intent already exist' do
      it 'returns the existing link_consumer_intent' do
        expected_link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          optional: false,
          blocked: false
        )

        actual_link_consumer_intent = subject.find_or_create_consumer_intent(
          link_consumer: link_consumer,
          original_link_name: 'test_original_link_name',
          link_type: 'test_link_type',
          optional: false,
          blocked: false
        )

        expect(actual_link_consumer_intent).to eq(expected_link_consumer_intent)
      end
    end

    context 'intent is missing' do
      it 'creates a new link_consumer_intent' do
        expected_intent = subject.find_or_create_consumer_intent(
          link_consumer: link_consumer,
          original_link_name: 'test_original_link_name',
          link_type: 'test_link_type',
          optional: true,
          blocked: false
        )

        actual_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
          link_consumer: link_consumer,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          optional: true,
          blocked: false
        )

        expect(actual_intent).to eq(expected_intent)
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
          type: 'control_owner_object_type'
        )

        actual_consumer = subject.find_consumer(
          deployment_model: deployment_model,
          instance_group_name: "control_instance_group",
          name: "control_owner_object_name"
        )
        expect(actual_consumer).to eq(expected_consumer)
      end
    end

    context 'link consumer does not exist' do
      it 'does not return a consumer' do
        actual_consumer = subject.find_consumer(
          deployment_model: deployment_model,
          instance_group_name: "control_instance_group",
          name: "control_owner_object_name"
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
        instance_group: 'test_instance_group'
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
        consumable: true
      )
    end

    let(:consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        name: 'test_consumer',
        type: 'job',
        instance_group: 'test_instance_group'
      )
    end

    let(:consumer_intent) do
      Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: consumer,
        original_name: 'test_original_link_name',
        type: 'test_link_type',
        optional: false,
        blocked: false
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
        instance_group: 'test_instance_group'
      )
    end
    let(:link_consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        name: 'test_deployment',
        type: 'test_deployment_type',
        instance_group: 'test_instance_group'
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
        consumable: true
      )
    end
    let(:consumer_intent) do
      Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: link_consumer,
        original_name: 'test_original_link_name',
        type: 'test_link_type',
        optional: false,
        blocked: false
      )
      end


    it 'creates a new link' do
      expected_link = subject.find_or_create_link(
        name: "test_link_name",
        provider_intent: provider_intent,
        consumer_intent: consumer_intent,
        link_content: "{}"
      )

      actual_link = Bosh::Director::Models::Links::Link.find(
        name: "test_link_name"
      )

      expect(actual_link).to eq(expected_link)
    end
  end
end