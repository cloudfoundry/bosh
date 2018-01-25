require 'spec_helper'

describe Bosh::Director::Links::LinksManager do
  subject {Bosh::Director::Links::LinksManager.new(logger)}

  let(:logger) {Logging::Logger.new('TestLogger')}
  # let(:event_logger) {Bosh::Director::EventLog::Log.new}

  let(:deployment_model) do
    Bosh::Director::Models::Deployment.create(
      name: 'test_deployment'
    )
  end

  describe '#add_provider' do
    context
  end

  describe '#find_or_create_provider' do
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
          name: "control_owner_object_name",
          type: "control_owner_object_type"
        )
        expect(actual_provider).to eq(expected_provider)
      end
    end

    context 'link provider does not exist' do
      it 'does not return a provider' do
        actual_provider = subject.find_provider(
          deployment_model: deployment_model,
          instance_group_name: "control_instance_group",
          name: "control_owner_object_name",
          type: "control_owner_object_type"
        )
        expect(actual_provider).to be_nil
      end
    end
  end

  describe '#find_providers' do
    context 'link providers exist' do
      it 'returns the existing providers for deployment' do
        expected_providers = [
          Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'control_instance_group',
            name: 'control_owner_object_name',
            type: 'control_owner_object_type'
          ),
          Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'control_instance_group',
            name: 'control_owner_object_name2',
            type: 'control_owner_object_type2'
          )
        ]

        actual_providers = subject.find_providers(
          deployment: deployment_model
        )
        expect(actual_providers).to eq(expected_providers)
      end
    end

    context 'no link providers exist' do
      it 'does not return a provider for deployment' do
        actual_providers = subject.find_providers(
          deployment: deployment_model
        )
        expect(actual_providers).to eq([])
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

    context 'intent already exists' do
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
          link_original_name: "test_original_link_name",
          link_type: "test_link_type"
        )

        expect(actual_intent).to eq(expected_intent)
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
      end
    end
  end

  describe '#find_provider_intent_*' do
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

          actual_intent = subject.find_provider_intent_by_alias(
            link_provider: link_provider,
            link_alias: 'test_link_alias',
            link_type: "test_link_type"
          )

          expect(actual_intent).to eq(expected_intent)
        end
      end

      context 'intent is missing' do
        it 'does not return a link_provider_intent' do
          actual_intent = subject.find_provider_intent_by_alias(
            link_provider: link_provider,
            link_alias: "test_link_alias",
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
          link_original_name: 'test_original_link_name',
          link_type: 'test_link_type'
        )

        expect(actual_link_consumer_intent).to eq(expected_link_consumer_intent)
      end
    end

    context 'intent is missing' do
      it 'creates a new link_consumer_intent' do
        expected_intent = subject.find_or_create_consumer_intent(
          link_consumer: link_consumer,
          link_original_name: 'test_original_link_name',
          link_type: 'test_link_type'
        )

        actual_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
          link_consumer: link_consumer,
          original_name: 'test_original_link_name',
          type: 'test_link_type',
          optional: false,
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
          name: "control_owner_object_name",
          type: 'control_owner_object_type'
        )
        expect(actual_consumer).to eq(expected_consumer)
      end
    end

    context 'link consumer does not exist' do
      it 'does not return a consumer' do
        actual_consumer = subject.find_consumer(
          deployment_model: deployment_model,
          instance_group_name: "control_instance_group",
          name: "control_owner_object_name",
          type: 'job'
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

  describe '#resolve_consumer' do
    let(:global_use_dns_entry) {true}

    context 'when dry_run flag is true' do
      let(:dry_run) {true}

      context 'when it is an explicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'job'
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
            metadata: metadata.to_json
          )
        end

        context 'and the provider exists' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )
          end

          it 'does not create a link' do
            subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            expect(Bosh::Director::Models::Links::Link.count).to eq(0)
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Can't resolve link 'provider_alias' in instance group 'ig1' on job 'c1' in deployment 'test_deployment'.")
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias',
              type: 'foo'
            )
          end

          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Multiple providers of name/alias 'provider_alias' found for job 'c1' and instance group 'ig1'. All of these match:
   pi1 aliased as 'provider_alias' (job: p1, instance group: ig1)
   pi2 aliased as 'provider_alias' (job: p1, instance group: ig1)")
          end
        end
      end

      context 'when it is an implicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'job'
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
            metadata: metadata.to_json
          )
        end

        context 'and the provider exists' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )
          end

          it 'does not create a link' do
            subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            expect(Bosh::Director::Models::Links::Link.count).to eq(0)
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Can't find link with type 'foo' for instance_group 'ig1' in deployment 'test_deployment'")
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig1',
              name: 'p1',
              type: 'job'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias2',
              type: 'foo'
            )
          end

          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Multiple providers of type 'foo' found for  job 'c1' and instance group 'ig1. All of these match:
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
            type: 'job'
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
            metadata: metadata.to_json
          )

          provider = Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'manual'
          )

          Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: provider,
            original_name: 'ci1',
            type: 'foo'
          )
        end

        it 'does not create a link' do
          subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
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
            instance_group: 'ig1'
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
            metadata: metadata.to_json
          )
        end

        context 'and the provider exists' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )
          end

          it 'creates a link' do
            subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            expect(Bosh::Director::Models::Links::Link.count).to eq(1)
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Can't resolve link 'provider_alias' in instance group 'ig1' on job 'c1' in deployment 'test_deployment'.")
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias',
              type: 'foo'
            )
          end

          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Multiple providers of name/alias 'provider_alias' found for job 'c1' and instance group 'ig1'. All of these match:
   pi1 aliased as 'provider_alias' (job: p1, instance group: ig1)
   pi2 aliased as 'provider_alias' (job: p1, instance group: ig1)")
          end
        end

        context 'and the provider is a different deployment' do
          let(:second_deployment_model) do
            Bosh::Director::Models::Deployment.create(
              name: 'second_deployment'
            )
          end

          let(:metadata) do
            {
              'explicit_link' => true,
              'from_deployment' => 'second_deployment'
            }
          end

          context 'and the deployment has a matching shared provider' do
            before do
              provider = Bosh::Director::Models::Links::LinkProvider.create(
                deployment: second_deployment_model,
                name: 'p2',
                type: 'job',
                instance_group: 'ig2'
              )

              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi2',
                name: 'provider_alias',
                type: 'foo',
                shared: true,
                content: {default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json
              )
            end

            it 'should create a link' do
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
              expect(Bosh::Director::Models::Links::Link.count).to eq(1)
            end
          end

          context 'and the deployment has an matching non-shared provider' do
            before do
              provider = Bosh::Director::Models::Links::LinkProvider.create(
                deployment: second_deployment_model,
                name: 'p2',
                type: 'job',
                instance_group: 'ig2'
              )

              Bosh::Director::Models::Links::LinkProviderIntent.create(
                link_provider: provider,
                original_name: 'pi2',
                name: 'provider_alias',
                type: 'foo',
                content: {default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json
              )
            end

            it 'should raise an error' do
              expect {
                subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
              }.to raise_error Bosh::Director::DeploymentInvalidLink, "Can't resolve link 'provider_alias' in instance group 'ig1' on job 'c1' in deployment 'second_deployment'."
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

          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              content: {default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json
            )
          end

          it 'creates a link where "address" is an IP address' do
            subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            links = Bosh::Director::Models::Links::Link.all
            expect(links.size).to eq(1)
            expect(JSON.parse(links.first.link_content)).to eq({'default_network' => 'netb', 'instances' => [{'address' => 'ip2'}]})
          end
        end

        context 'and requesting for DNS entries' do
          let(:metadata) do
            {
              'explicit_link' => true,
              'ip_addresses' => false,
            }
          end

          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo',
              content: {default_network: 'netb', instances: [{dns_addresses: {neta: 'dns1', netb: 'dns2'}, addresses: {neta: 'ip1', netb: 'ip2'}}]}.to_json
            )
          end

          it 'creates a link where "address" is a DNS entry' do
            subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            links = Bosh::Director::Models::Links::Link.all
            expect(links.size).to eq(1)
            expect(JSON.parse(links.first.link_content)).to eq({'default_network' => 'netb', 'instances' => [{'address' => 'dns2'}]})
          end
        end
      end

      context 'when it is an implicit consumer' do
        let(:consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            name: 'c1',
            type: 'job',
            instance_group: 'ig1'
          )
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            type: 'foo',
            metadata: {explicit_link: false}.to_json
          )
        end

        context 'and the provider exists' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )
          end

          it 'creates a link' do
            subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            expect(Bosh::Director::Models::Links::Link.count).to eq(1)
          end
        end

        context 'and the provider does NOT exist' do
          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Can't find link with type 'foo' for instance_group 'ig1' in deployment 'test_deployment'")
          end
        end

        context 'and the providers are ambiguous' do
          before do
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              name: 'p1',
              type: 'job',
              instance_group: 'ig1'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi1',
              name: 'provider_alias',
              type: 'foo'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'pi2',
              name: 'provider_alias2',
              type: 'foo'
            )
          end

          it 'raises an error' do
            expect {
              subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
            }.to raise_error(Bosh::Director::DeploymentInvalidLink, "Multiple providers of type 'foo' found for  job 'c1' and instance group 'ig1. All of these match:
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
            type: 'job'
          )
        end

        before do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: consumer,
            original_name: 'ci1',
            type: 'foo',
            metadata: {explicit_link: true}.to_json
          )

          provider = Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'ig1',
            name: 'c1',
            type: 'manual'
          )

          Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: provider,
            original_name: 'ci1',
            type: 'foo'
          )
        end

        it 'creates a link' do
          subject.resolve_consumer(consumer, global_use_dns_entry, dry_run)
          expect(Bosh::Director::Models::Links::Link.count).to eq(1)
        end
      end
    end
  end

  xdescribe '#cleanup_deployment' do
    let(:consumer) do
      Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        instance_group: 'ig1',
        name: 'c1',
        type: 'job'
      )
    end
    let(:consumer_intent) do
      Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: consumer,
        original_name: 'ci1',
        name: 'provider_alias',
        type: 'foo',
        metadata: metadata.to_json
      )
    end

    let(:metadata) do
      {
        'explicit_link' => true
      }
    end

    let(:provider) do
      Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        instance_group: 'ig1',
        name: 'p1',
        type: 'job'
      )
    end
    let(:provider_intent) do
      Bosh::Director::Models::Links::LinkProviderIntent.create(
        link_provider: provider,
        original_name: 'pi1',
        name: 'provider_alias',
        type: 'foo'
      )
    end

    before do
      Bosh::Director::Models::Links::Link.create(
        link_provider_intent: provider_intent,
        link_consumer_intent: consumer_intent,
        name: consumer_intent.original_name,
        link_content: '{}'
      )
    end

    # TODO LINKS: Update deployment should be where we do cleanup. Take a look at line
    # /Users/pivotal/workspace/bosh/src/bosh-director/lib/bosh/director/jobs/update_deployment.rb:112

    xit 'deletes all the consumers which was not created/updated in this task' do
      # subject.cleanup_deployment(deployment_model)
    end

    xit 'deletes all the providers which was not created/updated in this task' do

    end

    xit 'removes all the associated links for each consumer' do

    end
  end

  describe '#get_links_from_deployment' do
    before do
      consumer = Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        instance_group: 'ig1',
        name: 'c1',
        type: 'job'
      )

      consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: consumer,
        original_name: 'ci1',
        type: 'foo',
        metadata: {explicit_link: true}.to_json
      )

      provider = Bosh::Director::Models::Links::LinkProvider.create(
        deployment: deployment_model,
        instance_group: 'ig1',
        name: 'c1',
        type: 'manual'
      )

      provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
        link_provider: provider,
        original_name: 'ci1',
        type: 'foo'
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
      expect(result).to match(
        {
          "c1" => {
            "ci1" => {
              "foo" => "bar"
            }
          }
        }
      )
    end
  end
end
