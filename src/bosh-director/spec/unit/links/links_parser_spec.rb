require 'spec_helper'
require 'logging'

describe Bosh::Director::Links::LinksParser do
  let(:subject) do
    allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)
    Bosh::Director::Links::LinksParser.new
  end

  let(:links_manager) do
    instance_double(Bosh::Director::Links::LinksManager)
  end

  def create_release(release_name, version, provides: nil, consumes: nil, properties: nil)
    release_model = Bosh::Director::Models::Release.make(name: release_name)
    release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: version, release: release_model)

    release_spec = { properties: {} }
    release_spec[:properties] = properties if properties
    release_spec[:consumes] = consumes if consumes
    release_spec[:provides] = provides if provides

    # This is creating a job
    release_version_model.add_template(
      Bosh::Director::Models::Template.make(
        name: "#{release_name}_job_name_1",
        release: release_model,
        spec: release_spec,
      ),
    )

    release_version_model
  end

  let(:deployment_plan) do
    instance_double(Bosh::Director::DeploymentPlan::Planner).tap do |mock|
      allow(mock).to receive(:model).and_return(deployment_model)
    end
  end

  let(:deployment_model) do
    Bosh::Director::Models::Deployment.make
  end

  let(:release) do
    create_release('release1', '1', provides: release_providers, consumes: release_consumers, properties: release_properties)
  end

  let(:template) do
    release.templates.first
  end

  let(:release_providers) { nil }
  let(:release_consumers) { nil }
  let(:release_properties) { nil }

  let(:logger) do
    double(Logging::Logger)
  end

  before do
    allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
  end

  describe '#parse_migrated_from_providers_from_job' do
    let(:provider) { instance_double(Bosh::Director::Models::Links::LinkProvider) }
    let(:provider_intent) { instance_double(Bosh::Director::Models::Links::LinkProviderIntent) }

    let(:job_properties) do
      {}
    end

    let(:release_providers) do
      [{ name: 'link_1_name', type: 'link_1_type' }]
    end

    let(:job_spec) do
      {
        'name' => 'release1_job_name_1',
        'release' => 'release1',
        'provides' => {
          'link_1_name' => {
            'as' => 'link_1_name_alias',
            'shared' => true,
            'properties' => {},
          },
        },
      }
    end

    context 'when the job belongs to an instance group that is being migrated' do
      let(:release_providers) do
        [
          {
            name: 'chocolate',
            type: 'flavour',
          },
        ]
      end

      let(:deployment_model) { Bosh::Director::Models::Deployment.make(links_serial_id: serial_id) }
      let(:deployment_plan) { instance_double(Bosh::Director::DeploymentPlan::Planner) }
      let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment_model) }
      let(:serial_id) { 1 }
      let!(:provider_1) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'old-ig1',
          name: 'release1_job_name_1',
          type: 'job',
          serial_id: serial_id,
        )
      end

      let!(:provider_1_intent) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          link_provider: provider_1,
          original_name: 'chocolate',
          name: 'chocolate',
          type: 'flavour',
          shared: true,
          consumable: true,
          content: '{}',
          serial_id: serial_id,
        )
      end

      let(:link_providers) do
        [provider_1]
      end

      let(:job_spec) do
        {
          'name' => 'release1_job_name_1',
          'release' => 'release1',
          'properties' => job_properties,
          'provides' => {
            'chocolate' => {
              'as' => 'chocolate',
            },
          },
        }
      end

      let(:job_properties) do
        {
          'street' => 'Any Street',
        }
      end

      let(:migrated_from) do
        [
          { 'name' => 'old_ig1', 'az' => 'az1' },
          { 'name' => 'old_ig2', 'az' => 'az2' },
        ]
      end

      before do
        allow(deployment_model).to receive(:link_providers).and_return(link_providers)
      end

      it 'should update the instance_group name to match the existing provider' do
        expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig1',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(provider_1)
        expect(links_manager).to receive(:find_or_create_provider)
          .with(deployment_model: deployment_model, instance_group_name: 'old_ig1', name: 'release1_job_name_1', type: 'job')
          .and_return(provider_1)
        expect(links_manager).to receive(:find_or_create_provider_intent)
          .with(link_provider: provider_1, link_original_name: 'chocolate', link_type: 'flavour')
          .and_return(provider_1_intent)

        subject.parse_providers_from_job(
          job_spec,
          deployment_model,
          template,
          job_properties: job_properties,
          instance_group_name: 'new-ig',
          migrated_from: migrated_from,
        )
      end
    end

    context 'when there is a new job during a migrated_from deploy' do
      let(:migrated_from) do
        [
          { 'name' => 'old_ig1', 'az' => 'az1' },
          { 'name' => 'old_ig2', 'az' => 'az2' },
        ]
      end

      before do
        allow(provider_intent).to receive(:name=)
        allow(provider_intent).to receive(:metadata=)
        allow(provider_intent).to receive(:consumable=)
        allow(provider_intent).to receive(:shared=)
        allow(provider_intent).to receive(:save)
      end

      it 'chooses the new instance group name if there is no match' do
        expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig1',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(nil)
        expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig2',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(nil)
        expect(links_manager).to receive(:find_or_create_provider).with(
          deployment_model: deployment_model,
          instance_group_name: 'instance-group-name',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(provider)
        expect(links_manager).to receive(:find_or_create_provider_intent)
          .with(link_provider: provider, link_original_name: 'link_1_name', link_type: 'link_1_type')
          .and_return(provider_intent)

        subject.parse_providers_from_job(
          job_spec,
          deployment_plan.model,
          template,
          job_properties: job_properties,
          instance_group_name: 'instance-group-name',
          migrated_from: migrated_from,
        )
      end
    end
  end

  describe '#parse_migrated_from_consumers_from_job' do
    let(:consumer) { instance_double(Bosh::Director::Models::Links::LinkConsumer) }
    let(:consumer_intent) { instance_double(Bosh::Director::Models::Links::LinkConsumerIntent) }

    let(:job_properties) do
      {}
    end

    let(:release_consumers) do
      [{ name: 'link_1_name', type: 'link_1_type' }]
    end

    let(:job_spec) do
      {
        'name' => 'release1_job_name_1',
        'release' => 'release1',
        'consumes' => {
          'link_1_name' => {
            'from' => 'link_1_name_alias',
          },
        },
      }
    end

    context 'when the job belongs to an instance group that is being migrated' do
      let(:release_consumers) do
        [
          {
            name: 'chocolate',
            type: 'flavour',
          },
        ]
      end

      let(:deployment_model) { Bosh::Director::Models::Deployment.make(links_serial_id: serial_id) }
      let(:deployment_plan) { instance_double(Bosh::Director::DeploymentPlan::Planner) }
      let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment_model) }
      let(:serial_id) { 1 }
      let!(:consumer) do
        Bosh::Director::Models::Links::LinkConsumer.make(
          deployment: deployment_model,
          instance_group: 'old-ig1',
          name: 'foobar',
          type: 'job',
          serial_id: serial_id,
        )
      end

      let!(:consumer_intent) do
        Bosh::Director::Models::Links::LinkConsumerIntent.make(
          link_consumer: consumer,
          original_name: 'chocolate',
          name: 'chocolate',
          type: 'flavour',
          blocked: false,
          serial_id: serial_id,
        )
      end

      let(:link_consumers) do
        [consumer]
      end

      let(:job_spec) do
        {
          'name' => 'foobar',
          'release' => 'release1',
          'properties' => {},
          'consumes' => {
            'chocolate' => {
              'from' => 'chocolate',
            },
          },
        }
      end

      let(:migrated_from) do
        [
          { 'name' => 'old_ig1', 'az' => 'az1' },
          { 'name' => 'old_ig2', 'az' => 'az2' },
        ]
      end

      before do
        allow(deployment_model).to receive(:link_consumers).and_return(link_consumers)
      end

      it 'should update the instance_group name to match the existing provider' do
        expect(Bosh::Director::Models::Links::LinkConsumer).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig1',
          name: 'foobar',
          type: 'job',
        ).and_return(consumer)
        expect(links_manager).to receive(:find_or_create_consumer)
          .with(deployment_model: deployment_model, instance_group_name: 'old_ig1', name: 'foobar', type: 'job')
          .and_return(consumer)
        expect(links_manager).to receive(:find_or_create_consumer_intent)
          .with(link_consumer: consumer,
                link_original_name: 'chocolate',
                link_type: 'flavour',
                new_intent_metadata: { 'explicit_link' => true })
          .and_return(consumer_intent)

        subject.parse_consumers_from_job(
          job_spec,
          deployment_model,
          template,
          instance_group_name: 'new-ig',
          migrated_from: migrated_from,
        )
      end
    end

    context 'when there is a new job during a migrated_from deploy' do
      let(:migrated_from) do
        [
          { 'name' => 'old_ig1', 'az' => 'az1' },
          { 'name' => 'old_ig2', 'az' => 'az2' },
        ]
      end

      before do
        allow(consumer).to receive(:name)
        allow(consumer).to receive(:instance_group)
        allow(consumer_intent).to receive(:name=)
        allow(consumer_intent).to receive(:metadata=)
        allow(consumer_intent).to receive(:blocked=)
        allow(consumer_intent).to receive(:optional=)
        allow(consumer_intent).to receive(:save)
      end

      it 'chooses the new instance group name if there is no match' do
        expect(Bosh::Director::Models::Links::LinkConsumer).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig1',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(nil)
        expect(Bosh::Director::Models::Links::LinkConsumer).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig2',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(nil)
        expect(links_manager).to receive(:find_or_create_consumer).with(
          deployment_model: deployment_model,
          instance_group_name: 'instance-group-name',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(consumer)
        expect(links_manager).to receive(:find_or_create_consumer_intent).with(
          link_consumer: consumer,
          link_original_name: 'link_1_name',
          link_type: 'link_1_type',
          new_intent_metadata: { 'explicit_link' => true },
        ).and_return(consumer_intent)

        subject.parse_consumers_from_job(
          job_spec,
          deployment_plan.model,
          template,
          instance_group_name: 'instance-group-name',
          migrated_from: migrated_from,
        )
      end
    end
  end

  describe '#parse_providers_from_job' do
    let(:provider) { instance_double(Bosh::Director::Models::Links::LinkProvider) }
    let(:provider_intent) { instance_double(Bosh::Director::Models::Links::LinkProviderIntent) }

    let(:job_properties) do
      {}
    end

    context 'when the job does NOT define any provider in its release spec' do
      context 'when the manifest does not specify any providers' do
        let(:job_spec) do
          {
            'name' => 'job_1',
          }
        end

        it 'should not create any provider and intents' do
          expect(links_manager).to_not receive(:find_or_create_provider)
          expect(links_manager).to_not receive(:find_or_create_provider_intent)

          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: {},
            instance_group_name: 'instance-group-name',
          )
        end
      end
    end

    context 'when a job defines a provider in its release spec' do
      let(:release_providers) do
        [{ name: 'link_1_name', type: 'link_1_type' }]
      end

      context 'when the job exposes properties in the provided link' do
        let(:release_properties) do
          {
            'street' => { 'default' => 'Any Street' },
            'scope' => {},
            'division.router' => { 'default' => 'Canada' },
            'division.priority' => { 'default' => 1 },
            'division.enabled' => { 'default' => false },
            'division.sequence' => {},
          }
        end

        let(:release_providers) do
          [
            {
              name: 'link_1_name',
              type: 'link_1_type',
              properties:
              ['street', 'scope', 'division.priority', 'division.enabled', 'division.sequence'],
            },
          ]
        end

        let(:job_spec) do
          {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
            'properties' => job_properties,
          }
        end

        context 'when the job has properties specified' do
          let(:job_properties) do
            {
              'street' => 'Any Street',
              'division' => {
                'priority' => 'LOW',
                'sequence' => 'FIFO',
                'enabled' => true,
              },
            }
          end

          it 'should update the provider intent metadata with the correct mapped properties' do
            expected_provider_params = {
              deployment_model: deployment_plan.model,
              instance_group_name: 'instance-group-name',
              name: 'release1_job_name_1',
              type: 'job',
            }

            expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

            expected_provider_intent_params = {
              link_provider: provider,
              link_original_name: 'link_1_name',
              link_type: 'link_1_type',
            }
            expect(links_manager).to receive(:find_or_create_provider_intent)
              .with(expected_provider_intent_params)
              .and_return(provider_intent)

            mapped_properties = {
              'street' => 'Any Street',
              'scope' => nil,
              'division' => {
                'priority' => 'LOW',
                'enabled' => true,
                'sequence' => 'FIFO',
              },
            }

            expect(provider_intent).to receive(:name=).with('link_1_name')
            expect(provider_intent).to receive(:metadata=).with({
              mapped_properties: mapped_properties,
              custom: false,
              dns_aliases: nil,
            }.to_json)
            expect(provider_intent).to receive(:consumable=).with(true)
            expect(provider_intent).to receive(:shared=).with(false)
            expect(provider_intent).to receive(:save)
            subject.parse_providers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              job_properties: job_properties,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the job does not specify properties with default values' do
          let(:job_properties) do
            {}
          end

          it 'correctly uses the default values for provided links' do
            expected_provider_params = {
              deployment_model: deployment_plan.model,
              instance_group_name: 'instance-group-name',
              name: 'release1_job_name_1',
              type: 'job',
            }

            expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

            expected_provider_intent_params = {
              link_provider: provider,
              link_original_name: 'link_1_name',
              link_type: 'link_1_type',
            }
            expect(links_manager).to receive(:find_or_create_provider_intent)
              .with(expected_provider_intent_params)
              .and_return(provider_intent)

            mapped_properties = {
              'street' => 'Any Street',
              'scope' => nil,
              'division' => {
                'priority' => 1,
                'enabled' => false,
                'sequence' => nil,
              },
            }

            expect(provider_intent).to receive(:name=).with('link_1_name')
            expect(provider_intent).to receive(:metadata=).with({
              mapped_properties: mapped_properties,
              custom: false,
              dns_aliases: nil,
            }.to_json)
            expect(provider_intent).to receive(:consumable=).with(true)
            expect(provider_intent).to receive(:shared=).with(false)
            expect(provider_intent).to receive(:save)
            subject.parse_providers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              job_properties: job_properties,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the exposed property is not defined in the release' do
          let(:release_properties) do
            {
              'street' => { 'default' => 'Any Street' },
              'division.router' => { 'default' => 'Canada' },
              'division.priority' => { 'default' => 'NOW!' },
              'division.enabled' => { 'default' => false },
              'division.sequence' => {},
            }
          end

          let(:job_properties) do
            {
              'street' => 'Any Street',
              'division' => {
                'priority' => 'LOW',
                'sequence' => 'FIFO',
              },
            }
          end

          it 'raise an error' do
            expected_provider_params = {
              deployment_model: deployment_plan.model,
              instance_group_name: 'instance-group-name',
              name: 'release1_job_name_1',
              type: 'job',
            }

            expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)
            expect(links_manager).to_not receive(:find_or_create_provider_intent)
            expect(provider_intent).to_not receive(:metadata=)
            expect(provider_intent).to_not receive(:shared=)
            expect(provider_intent).to_not receive(:name=)
            expect(provider_intent).to_not receive(:save)

            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error(
              RuntimeError,
              'Link property scope in template release1_job_name_1 is not defined in release spec',
            )
          end
        end
      end

      context 'when a job does NOT define a provides section in manifest' do
        let(:job_spec) do
          {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
          }
        end

        it 'should add correct link providers and link providers intent to the DB' do
          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'release1_job_name_1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
          }
          expect(links_manager).to receive(:find_or_create_provider_intent)
            .with(expected_provider_intent_params)
            .and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:metadata=).with({
            mapped_properties: {},
            custom: false,
            dns_aliases: nil,
          }.to_json)
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)

          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: job_properties,
            instance_group_name: 'instance-group-name',
          )
        end
      end

      context 'when a job defines a provides section in manifest' do
        let(:job_spec) do
          {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
            'provides' => {
              'link_1_name' => {
                'as' => 'link_1_name_alias',
                'aliases' => [{ domain: 'alias_configuration' }],
                'shared' => true,
              },
            },
          }
        end

        let(:job_properties) do
          {}
        end

        it 'should add correct link providers and link providers intent to the DB' do
          original_job_spec = Bosh::Common::DeepCopy.copy(job_spec)

          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'release1_job_name_1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
          }
          expect(links_manager).to receive(:find_or_create_provider_intent)
            .with(expected_provider_intent_params)
            .and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name_alias')
          expect(provider_intent).to receive(:metadata=).with({
            mapped_properties: {},
            custom: false,
            dns_aliases: [{ domain: 'alias_configuration' }],
          }.to_json)
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:shared=).with(true)
          expect(provider_intent).to receive(:save)
          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: job_properties,
            instance_group_name: 'instance-group-name',
          )
          expect(job_spec).to eq(original_job_spec)
        end
      end

      context 'when a job defines a nil provides section in the manifest' do
        let(:job_spec) do
          {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
            'provides' => {
              'link_1_name' => 'nil',
            },
          }
        end

        it 'should set the intent consumable to false' do
          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'release1_job_name_1',
            type: 'job',
          }
          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
          }
          expect(links_manager).to receive(:find_or_create_provider_intent)
            .with(expected_provider_intent_params)
            .and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:metadata=).with({
            mapped_properties: {},
            custom: false,
            dns_aliases: nil,
          }.to_json)
          expect(provider_intent).to receive(:consumable=).with(false)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)
          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: job_properties,
            instance_group_name: 'instance-group-name',
          )
        end
      end

      context 'provider validation' do
        before do
          expect(links_manager).to receive(:find_or_create_provider)
          expect(links_manager).to_not receive(:find_or_create_provider_intent)
        end

        context 'when a manifest job explicitly defines name or type for a provider' do
          it 'should fail if there is a name' do
            job_spec = {
              'name' => 'release1_job_name_1',
              'release' => 'release1',
              'provides' => {
                'link_1_name' => {
                  'name' => 'better_link_1_name',
                  'shared' => true,
                },
              },
            }

            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error(RuntimeError, "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name'"\
                                             " in job 'release1_job_name_1' in instance group 'instance-group-name'."\
                                             ' Please provide these keys in the release only.')
          end

          it 'should fail if there is a type' do
            job_spec = {
              'name' => 'release1_job_name_1',
              'release' => 'release1',
              'provides' => {
                'link_1_name' => {
                  'type' => 'better_link_1_type',
                  'shared' => true,
                },
              },
            }

            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error(RuntimeError, "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name'"\
                                             " in job 'release1_job_name_1' in instance group 'instance-group-name'."\
                                             ' Please provide these keys in the release only.')
          end

          # TODO: Should not fail if no properties in spec or manifest
        end

        context 'when the provides section is not a hash' do
          it 'raise an error' do
            job_spec = {
              'name' => 'release1_job_name_1',
              'release' => 'release1',
              'provides' => {
                'link_1_name' => ['invalid stuff'],
              },
            }

            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error(RuntimeError, "Provider 'link_1_name' in job 'release1_job_name_1' in instance group"\
                                " 'instance-group-name' specified in the manifest should only be a hash or string 'nil'")
          end

          context "when it is a string that is not 'nil'" do
            it 'raise an error' do
              job_spec = {
                'name' => 'release1_job_name_1',
                'release' => 'release1',
                'provides' => {
                  'link_1_name' => 'invalid stuff',
                },
              }

              expect do
                subject.parse_providers_from_job(
                  job_spec,
                  deployment_plan.model,
                  template,
                  job_properties: job_properties,
                  instance_group_name: 'instance-group-name',
                )
              end.to raise_error(RuntimeError, "Provider 'link_1_name' in job 'release1_job_name_1' in instance group"\
                                  " 'instance-group-name' specified in the manifest should only be a hash or string 'nil'")
            end
          end
        end
      end

      context 'when a manifest job defines a provider which is not specified in the release' do
        it 'should fail because it does not match the release' do
          job_spec = {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
            'provides' => {
              'new_link_name' => {
                'shared' => 'false',
              },
            },
          }

          expect(links_manager).to receive(:find_or_create_provider).and_return(provider)
          expect(links_manager).to receive(:find_or_create_provider_intent).and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:metadata=).with({
            mapped_properties: {},
            custom: false,
            dns_aliases: nil,
          }.to_json)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)
          expect(logger).to receive(:warn).with("Manifest defines unknown providers:\n"\
                                                "  - Job 'release1_job_name_1' does not define link provider 'new_link_name'"\
                                                ' in the release spec')

          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: job_properties,
            instance_group_name: 'instance-group-name',
          )
        end
      end
    end

    context 'when custom_provider_definitions is defined' do
      let(:job_spec) do
        {
          'name' => 'release1_job_name_1',
          'release' => 'release1',
          'custom_provider_definitions' => custom_providers,
        }
      end

      let(:custom_providers) do
        [{ 'name' => 'my_special_provider', 'type' => 'address' }]
      end

      before do
        allow(provider_intent).to receive(:name=).with('my_special_provider')
        allow(provider_intent).to receive(:shared=)
        allow(provider_intent).to receive(:consumable=)
        allow(provider_intent).to receive(:save)
      end

      it 'creates the appropriate provider and provider intents' do
        expect(links_manager).to receive(:find_or_create_provider).with(
          deployment_model: deployment_model,
          instance_group_name: 'instance-group-name',
          name: 'release1_job_name_1',
          type: 'job',
        ).and_return(provider)

        expect(links_manager).to receive(:find_or_create_provider_intent).with(
          link_provider: provider,
          link_original_name: 'my_special_provider',
          link_type: 'address',
        ).and_return(provider_intent)

        expect(provider_intent).to receive(:metadata=) do |metadata|
          expect(metadata['custom']).to be_truthy
        end

        subject.parse_providers_from_job(
          job_spec,
          deployment_model,
          template,
          job_properties: job_properties,
          instance_group_name: 'instance-group-name',
        )
      end

      context 'but custom_provider_definitions is an empty array' do
        let(:custom_providers) { [] }

        it 'should not create any providers' do
          expect(links_manager).to_not receive(:find_or_create_provider)
          expect(links_manager).to_not receive(:find_or_create_provider_intent)

          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: job_properties,
            instance_group_name: 'instance-group-name',
          )
        end
      end

      context 'when definition is invalid' do
        context 'when the custom definition does not specify name' do
          let(:custom_providers) do
            [
              {
                'type' => 'address',
              },
            ]
          end

          it 'should return an error' do
            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error("Name for custom link provider definition in manifest in job 'release1_job_name_1'"\
                               " in instance group 'instance-group-name' must be a valid non-empty string.")
          end
        end

        context 'when the custom definition specifies an empty name' do
          let(:custom_providers) do
            [
              {
                'name' => '',
                'type' => 'address',
              },
            ]
          end

          it 'should return an error' do
            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error("Name for custom link provider definition in manifest in job 'release1_job_name_1'"\
                               " in instance group 'instance-group-name' must be a valid non-empty string.")
          end
        end

        context 'when the custom definition does not specify a type' do
          let(:custom_providers) do
            [
              {
                'name' => 'custom_link_name',
              },
            ]
          end

          it 'should return an error' do
            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error("Type for custom link provider definition in manifest in job 'release1_job_name_1'"\
                               " in instance group 'instance-group-name' must be a valid non-empty string.")
          end
        end

        context 'when the custom definition specifies an empty type' do
          let(:custom_providers) do
            [
              {
                'name' => 'custom_link_name',
                'type' => '',
              },
            ]
          end

          it 'should return an error' do
            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error("Type for custom link provider definition in manifest in job 'release1_job_name_1'"\
                               " in instance group 'instance-group-name' must be a valid non-empty string.")
          end
        end

        context 'when the custom definition specifies an invalid name and type' do
          let(:custom_providers) do
            [
              {
                'name' => '',
                'type' => '',
              },
            ]
          end

          # rubocop:disable Style/MultilineBlockChain
          it 'should return an error' do
            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error do |e|
              expect(e.message).to include("Name for custom link provider definition in manifest in job 'release1_job_name_1'"\
                                           " in instance group 'instance-group-name' must be a valid non-empty string.")
              expect(e.message).to include("Type for custom link provider definition in manifest in job 'release1_job_name_1'"\
                                           " in instance group 'instance-group-name' must be a valid non-empty string.")
            end
          end
          # rubocop:enable Style/MultilineBlockChain
        end

        context 'when the custom definition is missing both name and type' do
          let(:custom_providers) { [{}] }

          # rubocop:disable Style/MultilineBlockChain
          it 'should return an error' do
            expect do
              subject.parse_providers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                job_properties: job_properties,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error do |e|
              expect(e.message).to include("Name for custom link provider definition in manifest in job 'release1_job_name_1'"\
                                           " in instance group 'instance-group-name' must be a valid non-empty string.")
              expect(e.message).to include("Type for custom link provider definition in manifest in job 'release1_job_name_1'"\
                                           " in instance group 'instance-group-name' must be a valid non-empty string.")
            end
          end
          # rubocop:enable Style/MultilineBlockChain
        end
      end

      context 'when the custom definition has the same name as a provider from release definition' do
        let(:release_providers) do
          [{ name: 'link_1_name', type: 'link_1_type' }]
        end

        let(:custom_providers) do
          [
            {
              'name' => 'link_1_name',
              'type' => 'address',
            },
          ]
        end

        it 'should raise an error' do
          expect do
            subject.parse_providers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              job_properties: job_properties,
              instance_group_name: 'instance-group-name',
            )
          end.to raise_error("Custom provider 'link_1_name' in job 'release1_job_name_1' in instance group 'instance-group-name'"\
                             " is already defined in release 'release1'")
        end
      end

      context 'when the custom definitions conflict with each other' do
        let(:custom_providers) do
          [
            {
              'name' => 'link_1_name',
              'type' => 'address',
            },
            {
              'name' => 'link_1_name',
              'type' => 'smurf',
            },
            {
              'name' => 'link_2_name',
              'type' => 'address',
            },
            {
              'name' => 'link_2_name',
              'type' => 'smurf',
            },
          ]
        end

        # rubocop:disable Style/MultilineBlockChain
        it 'should raise an error' do
          expect do
            subject.parse_providers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              job_properties: job_properties,
              instance_group_name: 'instance-group-name',
            )
          end.to raise_error do |e|
            expect(e.message).to match("Custom provider 'link_1_name' in job 'release1_job_name_1' in instance group"\
                                       " 'instance-group-name' is defined multiple times in manifest.")
            expect(e.message).to match("Custom provider 'link_2_name' in job 'release1_job_name_1' in instance group"\
                                       " 'instance-group-name' is defined multiple times in manifest.")
          end
        end
        # rubocop:enable Style/MultilineBlockChain
      end
    end
  end

  describe '#parse_consumers_from_job' do
    let(:consumer) { instance_double(Bosh::Director::Models::Links::LinkConsumer) }
    let(:consumer_intent) { instance_double(Bosh::Director::Models::Links::LinkConsumerIntent) }

    context 'when the job does NOT define any consumer in its release spec' do
      context 'when the manifest does not specify any providers' do
        let(:job_spec) do
          {
            'name' => 'job_1',
          }
        end

        it 'should not create any provider and intents' do
          expect(links_manager).to_not receive(:find_or_create_consumer)
          expect(links_manager).to_not receive(:find_or_create_consumer_intent)

          subject.parse_providers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            job_properties: {},
            instance_group_name: 'instance-group-name',
          )
        end
      end
    end

    context 'when a job defines a consumer in its release spec' do
      context 'when consumer is implicit (not specified in the deployment manifest)' do
        let(:release_consumers) do
          [
            { name: 'link_1_name', type: 'link_1_type' },
          ]
        end

        let(:job_spec) do
          {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
          }
        end

        it 'should add the consumer and consumer intent to the DB' do
          expected_consumer_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'release1_job_name_1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_consumer).with(expected_consumer_params).and_return(consumer)

          expected_consumer_intent_params = {
            link_consumer: consumer,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
            new_intent_metadata: { 'explicit_link' => false },
          }

          expect(links_manager).to receive(:find_or_create_consumer_intent)
            .with(expected_consumer_intent_params)
            .and_return(consumer_intent)

          expect(consumer_intent).to receive(:name=).with('link_1_name')
          expect(consumer_intent).to receive(:blocked=).with(false)
          expect(consumer_intent).to receive(:optional=).with(false)
          expect(consumer_intent).to receive(:save)

          subject.parse_consumers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            instance_group_name: 'instance-group-name',
          )
        end

        context 'when the release spec defines the link as optional' do
          let(:release_consumers) do
            [
              { name: 'link_1_name', type: 'link_1_type', optional: true },
            ]
          end

          it 'sets consumer intent optional field to true' do
            expect(links_manager).to receive(:find_or_create_consumer).and_return(consumer)
            expect(links_manager).to receive(:find_or_create_consumer_intent).and_return(consumer_intent)

            expect(consumer_intent).to receive(:name=).with('link_1_name')
            expect(consumer_intent).to receive(:blocked=).with(false)
            expect(consumer_intent).to receive(:optional=).with(true)
            expect(consumer_intent).to receive(:save)

            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end
        end
      end

      context 'when consumer is explicit (specified in the deployment manifest)' do
        let(:release_consumers) do
          [{ name: 'link_1_name', type: 'link_1_type' }]
        end
        let(:consumer_options) do
          { 'from' => 'snoopy' }
        end
        let(:manifest_link_consumers) do
          { 'link_1_name' => consumer_options }
        end
        let(:job_spec) do
          {
            'name' => 'release1_job_name_1',
            'release' => 'release1',
            'consumes' => manifest_link_consumers,
          }
        end

        before do
          allow(consumer).to receive(:name)
          allow(consumer).to receive(:instance_group)
          allow(links_manager).to receive(:find_or_create_consumer).and_return(consumer)
          allow(links_manager).to receive(:find_or_create_consumer_intent).and_return(consumer_intent)
        end

        it 'should add the consumer and consumer intent to the DB' do
          original_job_spec = Bosh::Common::DeepCopy.copy(job_spec)

          expected_consumer_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'release1_job_name_1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_consumer).with(expected_consumer_params).and_return(consumer)

          expected_consumer_intent_params = {
            link_consumer: consumer,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
            new_intent_metadata: { 'explicit_link' => true },
          }

          expect(links_manager).to receive(:find_or_create_consumer_intent)
            .with(expected_consumer_intent_params)
            .and_return(consumer_intent)

          expect(consumer_intent).to receive(:name=).with('snoopy')
          expect(consumer_intent).to receive(:blocked=).with(false)
          expect(consumer_intent).to receive(:optional=).with(false)
          expect(consumer_intent).to receive(:save)

          subject.parse_consumers_from_job(
            job_spec,
            deployment_plan.model,
            template,
            instance_group_name: 'instance-group-name',
          )
          expect(job_spec).to eq(original_job_spec)
        end

        context 'when the consumer alias is separated by "."' do
          let(:consumer_options) do
            { 'from' => 'foo.bar.baz' }
          end

          before do
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:metadata=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          it 'should use the last segment in "from" as the alias' do
            expect(consumer_intent).to receive(:name=).with('baz')
            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the consumer is explicitly set to nil' do
          let(:consumer_options) { 'nil' }

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:metadata=)
            allow(consumer_intent).to receive(:save)
          end

          it 'should set the consumer intent blocked' do
            expect(consumer_intent).to receive(:blocked=).with(true)

            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the consumer does not have a from key' do
          let(:consumer_options) do
            {}
          end

          before do
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:metadata=)
            allow(consumer_intent).to receive(:save)
          end

          it 'should set the consumer intent name to original name' do
            expect(consumer_intent).to receive(:name=).with('link_1_name')

            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the consumer specifies a specific network' do
          let(:consumer_options) do
            { 'network' => 'charlie' }
          end

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          it 'will add specified network name to the metadata' do
            allow(consumer_intent).to receive(:metadata=).with({ explicit_link: true, network: 'charlie' }.to_json)
            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the consumer specifies to use ip addresses only' do
          let(:consumer_options) do
            { 'ip_addresses' => true }
          end

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          it 'will set the ip_addresses flag in the metadata to true' do
            allow(consumer_intent).to receive(:metadata=).with({ explicit_link: true, ip_addresses: true }.to_json)
            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end
        end

        context 'when the consumer specifies to use a deployment' do
          let(:consumer_options) do
            { 'deployment' => 'some-other-deployment' }
          end

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          context 'when the provider deployment exists' do
            before do
              Bosh::Director::Models::Deployment.make(name: 'some-other-deployment')
            end

            it 'will set the from_deployment flag in the metadata to the provider deployment name' do
              metadata_parameters = { explicit_link: true, from_deployment: 'some-other-deployment' }.to_json
              allow(consumer_intent).to receive(:metadata=).with(metadata_parameters)
              subject.parse_consumers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                instance_group_name: 'instance-group-name',
              )
            end
          end

          context 'when the provider deployment exists' do
            it 'raise an error' do
              expect do
                subject.parse_consumers_from_job(
                  job_spec,
                  deployment_plan.model,
                  template,
                  instance_group_name: 'instance-group-name',
                )
              end.to raise_error "Link 'link_1_name' in job 'release1_job_name_1' from instance group 'instance-group-name'"\
                                 " consumes from deployment 'some-other-deployment', but the deployment does not exist."
            end
          end
        end

        context 'when the consumer specifies the name key in the consumes section of the manifest' do
          let(:consumer_options) do
            { 'name' => 'i should not be here' }
          end

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
            allow(consumer_intent).to receive(:metadata=)
          end

          it 'raise an error' do
            expect do
              subject.parse_consumers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name'"\
                               " in job 'release1_job_name_1' in instance group 'instance-group-name'."\
                               ' Please provide these keys in the release only.'
          end
        end

        context 'when the consumer specifies the type key in the consumes section of the manifest' do
          let(:consumer_options) do
            { 'type' => 'i should not be here' }
          end

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
            allow(consumer_intent).to receive(:metadata=)
          end

          it 'raise an error' do
            expect do
              subject.parse_consumers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                instance_group_name: 'instance-group-name',
              )
            end.to raise_error "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name'"\
                               " in job 'release1_job_name_1' in instance group 'instance-group-name'."\
                               ' Please provide these keys in the release only.'
          end
        end

        context 'when processing manual links' do
          let(:manual_provider) { instance_double(Bosh::Director::Models::Links::LinkProvider) }
          let(:manual_provider_intent) { instance_double(Bosh::Director::Models::Links::LinkProviderIntent) }
          let(:consumer_options) do
            {
              'instances' => 'instances definition',
              'properties' => 'property definitions',
              'address' => 'address definition',
            }
          end

          before do
            allow(deployment_model).to receive(:name).and_return('charlie')

            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)

            allow(consumer_intent).to receive(:original_name).and_return('link_1_name')
            allow(consumer_intent).to receive(:type).and_return('link_1_type')

            allow(consumer).to receive(:deployment).and_return(deployment_model)
            allow(consumer).to receive(:instance_group).and_return('consumer_instance_group')
            allow(consumer).to receive(:name).and_return('consumer_name')

            allow(manual_provider_intent).to receive(:content=)
            allow(manual_provider_intent).to receive(:name=)
            expect(manual_provider_intent).to receive(:save)
          end

          it 'adds manual_link flag as true to the consumer intents metadata' do
            allow(links_manager).to receive(:find_or_create_provider).and_return(manual_provider)
            allow(links_manager).to receive(:find_or_create_provider_intent).and_return(manual_provider_intent)

            expect(links_manager).to receive(:find_or_create_consumer_intent).with(link_consumer: anything,
                                                                                   link_original_name: anything,
                                                                                   link_type: anything,
                                                                                   new_intent_metadata: {
                                                                                     'explicit_link' => true,
                                                                                     'manual_link' => true,
                                                                                   })

            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end

          it 'creates a manual provider in the database' do
            allow(links_manager).to receive(:find_or_create_provider_intent).and_return(manual_provider_intent)

            expect(links_manager).to receive(:find_or_create_provider).with(
              deployment_model: deployment_model,
              instance_group_name: 'consumer_instance_group',
              name: 'consumer_name',
              type: 'manual',
            ).and_return(manual_provider)

            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end

          it 'creates a manual provider intent in the database' do
            allow(links_manager).to receive(:find_or_create_provider).and_return(manual_provider)

            expect(links_manager).to receive(:find_or_create_provider_intent).with(
              link_provider: manual_provider,
              link_original_name: 'link_1_name',
              link_type: 'link_1_type',
            ).and_return(manual_provider_intent)

            expected_content = {
              'instances' => 'instances definition',
              'properties' => 'property definitions',
              'address' => 'address definition',
              'deployment_name' => 'charlie',
            }

            expect(manual_provider_intent).to receive(:name=).with('link_1_name')
            expect(manual_provider_intent).to receive(:content=).with(expected_content.to_json)

            subject.parse_consumers_from_job(
              job_spec,
              deployment_plan.model,
              template,
              instance_group_name: 'instance-group-name',
            )
          end

          context 'when the manual link has keys that are not whitelisted' do
            let(:consumer_options) do
              {
                'instances' => 'instances definition',
                'properties' => 'property definitions',
                'address' => 'address definition',
                'foo' => 'bar',
                'baz' => 'boo',
              }
            end

            it 'should only add whitelisted values' do
              allow(links_manager).to receive(:find_or_create_provider).and_return(manual_provider)

              expect(links_manager).to receive(:find_or_create_provider_intent).with(
                link_provider: manual_provider,
                link_original_name: 'link_1_name',
                link_type: 'link_1_type',
              ).and_return(manual_provider_intent)

              expected_content = {
                'instances' => 'instances definition',
                'properties' => 'property definitions',
                'address' => 'address definition',
                'deployment_name' => 'charlie',
              }

              expect(manual_provider_intent).to receive(:content=).with(expected_content.to_json)

              subject.parse_consumers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                instance_group_name: 'instance-group-name',
              )
            end
          end
        end

        context 'consumer validation' do
          # rubocop:disable Style/MultilineBlockChain
          context "when 'instances' and 'from' keywords are specified at the same time" do
            let(:consumer_options) do
              { 'from' => 'snoopy', 'instances' => ['1.2.3.4'] }
            end

            it 'should raise an error' do
              expect do
                subject.parse_consumers_from_job(
                  job_spec,
                  deployment_plan.model,
                  template,
                  instance_group_name: 'instance-group-name',
                )
              end.to raise_error do |e|
                expect(e.message).to include("Cannot specify both 'instances' and 'from' keys for link 'link_1_name'"\
                                             " in job 'release1_job_name_1' in instance group 'instance-group-name'.")
              end
            end
          end

          context "when 'properties' and 'from' keywords are specified at the same time" do
            let(:consumer_options) do
              { 'from' => 'snoopy', 'properties' => { 'meow' => 'cat' } }
            end

            it 'should raise an error' do
              expect do
                subject.parse_consumers_from_job(
                  job_spec,
                  deployment_plan.model,
                  template,
                  instance_group_name: 'instance-group-name',
                )
              end.to raise_error do |e|
                expect(e.message).to include("Cannot specify both 'properties' and 'from' keys for link 'link_1_name'"\
                                             " in job 'release1_job_name_1' in instance group 'instance-group-name'.")
              end
            end
          end

          context "when 'properties' is defined but 'instances' is not" do
            let(:consumer_options) do
              { 'properties' => 'snoopy' }
            end

            it 'should raise an error' do
              expect do
                subject.parse_consumers_from_job(
                  job_spec,
                  deployment_plan.model,
                  template,
                  instance_group_name: 'instance-group-name',
                )
              end.to raise_error do |e|
                expect(e.message).to include("Cannot specify 'properties' without 'instances' for link 'link_1_name'"\
                                             " in job 'release1_job_name_1' in instance group 'instance-group-name'.")
              end
            end
          end

          context "when 'ip_addresses' value is not a boolean" do
            let(:consumer_options) do
              { 'ip_addresses' => 'not a boolean' }
            end

            it 'should raise an error' do
              expect do
                subject.parse_consumers_from_job(
                  job_spec,
                  deployment_plan.model,
                  template,
                  instance_group_name: 'instance-group-name',
                )
              end.to raise_error do |e|
                expect(e.message).to include("Cannot specify non boolean values for 'ip_addresses' field for link 'link_1_name'"\
                                             " in job 'release1_job_name_1' in instance group 'instance-group-name'.")
              end
            end
          end
          # rubocop:enable Style/MultilineBlockChain

          context 'when the manifest specifies consumers that are not defined in the release spec' do
            before do
              allow(consumer_intent).to receive(:name=)
              allow(consumer_intent).to receive(:blocked=)
              allow(consumer_intent).to receive(:optional=)
              allow(consumer_intent).to receive(:metadata=)
              allow(consumer_intent).to receive(:save)

              manifest_link_consumers['first_undefined'] = {}
              manifest_link_consumers['second_undefined'] = {}
            end

            it 'should raise an error for each undefined consumer' do
              expected_error = [
                'Manifest defines unknown consumers:',
                "  - Job 'release1_job_name_1' does not define link consumer 'first_undefined' in the release spec",
                "  - Job 'release1_job_name_1' does not define link consumer 'second_undefined' in the release spec",
              ].join("\n")
              expect(logger).to receive(:warn).with(expected_error)

              subject.parse_consumers_from_job(
                job_spec,
                deployment_plan.model,
                template,
                instance_group_name: 'instance-group-name',
              )
            end
          end

          context 'when the manifest specifies consumers that are not hashes or "nil" string' do
            context 'consumer is an array' do
              let(:consumer_options) { ['Unaccepted type array'] }

              it 'should raise an error' do
                expect do
                  subject.parse_consumers_from_job(
                    job_spec,
                    deployment_plan.model,
                    template,
                    instance_group_name: 'instance-group-name',
                  )
                end.to raise_error "Consumer 'link_1_name' in job 'release1_job_name_1' in instance group 'instance-group-name'"\
                                   " specified in the manifest should only be a hash or string 'nil'"
              end
            end

            context 'consumer is a string that is not "nil"' do
              let(:consumer_options) { 'Unaccepted string value' }

              it 'should raise an error' do
                expect do
                  subject.parse_consumers_from_job(
                    job_spec,
                    deployment_plan.model,
                    template,
                    instance_group_name: 'instance-group-name',
                  )
                end.to raise_error "Consumer 'link_1_name' in job 'release1_job_name_1' in instance group 'instance-group-name'"\
                                   " specified in the manifest should only be a hash or string 'nil'"
              end
            end

            context 'consumer is empty or set to null' do
              let(:consumer_options) { nil }

              it 'should raise an error' do
                expect do
                  subject.parse_consumers_from_job(
                    job_spec,
                    deployment_plan.model,
                    template,
                    instance_group_name: 'instance-group-name',
                  )
                end.to raise_error "Consumer 'link_1_name' in job 'release1_job_name_1' in instance group 'instance-group-name'"\
                                   " specified in the manifest should only be a hash or string 'nil'"
              end
            end
          end
        end
      end
    end
  end

  describe '#parse_provider_from_disk' do
    let(:provider) { instance_double(Bosh::Director::Models::Links::LinkProvider) }
    let(:provider_intent) { instance_double(Bosh::Director::Models::Links::LinkProviderIntent) }

    context 'when persistent disks are well formatted' do
      it 'parses successfully' do
        expected_provider_params = {
          deployment_model: deployment_plan.model,
          instance_group_name: 'instance-group-name',
          name: 'instance-group-name',
          type: 'disk',
        }
        expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)
        expected_provider_intent_params = {
          link_provider: provider,
          link_original_name: 'my-disk',
          link_type: 'disk',
        }
        expect(links_manager).to receive(:find_or_create_provider_intent)
          .with(expected_provider_intent_params)
          .and_return(provider_intent)
        expect(provider_intent).to receive(:shared=)
        expect(provider_intent).to receive(:name=).with('my-disk')
        expect(provider_intent).to receive(:content=)
        expect(provider_intent).to receive(:save)
        #  expect not to raise an error
        disk_spec = { 'name' => 'my-disk', 'type' => 'disk-type-small' }
        subject.parse_provider_from_disk(disk_spec, deployment_plan.model, 'instance-group-name')
      end
    end
  end

  describe '#parse_consumers_from_variable' do
    let(:consumer) { instance_double(Bosh::Director::Models::Links::LinkConsumer) }
    let(:consumer_intent) { instance_double(Bosh::Director::Models::Links::LinkConsumerIntent) }
    let(:link_original_name) { 'foo' }
    let(:link_type) { 'address' }
    let(:link_alternative_name) { 'foo' }
    let(:expected_consumer_intent_params) do
      {
        link_consumer: consumer,
        link_original_name: link_original_name,
        link_type: link_type,
        new_intent_metadata: {
          'explicit_link' => explicit_link,
          'wildcard' => wildcard,
        },
      }
    end

    let(:explicit_link) { true }
    let(:wildcard) { false }

    let(:expected_consumer_params) do
      {
        deployment_model: deployment_plan.model,
        instance_group_name: '',
        name: 'bbs',
        type: 'variable',
      }
    end

    context 'when requirements are satisfied' do
      before do
        expect(links_manager).to receive(:find_or_create_consumer_intent)
          .with(expected_consumer_intent_params)
          .and_return(consumer_intent)
        expect(links_manager).to receive(:find_or_create_consumer).with(expected_consumer_params).and_return(consumer)
        expect(consumer_intent).to receive(:name=).with(link_alternative_name)
        expect(consumer_intent).to receive(:save)
      end


      context 'when the variable defines "alternative_name" consumer' do
        let(:link_original_name) { 'alternative_name' }

        it 'makes consumer and consumer intent' do
          variable_spec = {
            'name' => 'bbs',
            'type' => 'certificate',
            'consumes' => {
              'alternative_name' => { 'from' => 'foo' },
            },
          }

          subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
        end

        context "when the 'link_type' is specified on the link" do
          let(:link_type) { 'overridden_type' }

          it "takes the link_type instead of using the default of 'address'" do
            variable_spec = {
              'name' => 'bbs',
              'type' => 'certificate',
              'consumes' => {
                'alternative_name' => {
                  'from' => 'foo',
                  'link_type' => 'overridden_type',
                },
              },
            }

            subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
          end
        end

        context 'and the `from` is not specified' do
          let(:link_alternative_name) { 'alternative_name' }

          it 'makes consumer and consumer intent' do
            variable_spec = {
              'name' => 'bbs',
              'type' => 'certificate',
              'consumes' => {
                'alternative_name' => {},
              },
            }
            subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
          end
        end

        context 'and the `wildcard` is true' do
          let(:wildcard) { true }

          it 'makes consumer and consumer intent' do
            variable_spec = {
              'name' => 'bbs',
              'type' => 'certificate',
              'consumes' => {
                'alternative_name' => {
                  'from' => 'foo',
                  'properties' => { 'wildcard' => true },
                },
              },
            }
            subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
          end
        end
      end
    end

    context 'when requirements are not satisfied' do
      context 'when the variable does not define a consumes block' do
        it 'should not create any implicit consumers or intents' do
          expect(links_manager).to_not receive(:find_or_create_consumer)
          expect(links_manager).to_not receive(:find_or_create_consumer_intent)

          variable_spec = {
            'name' => 'bbs',
            'type' => 'certificate',
          }
          subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
        end
      end

      context 'when the variable does not define any consumers in the consumes block' do
        it 'should not create any implicit consumers or intents' do
          expect(links_manager).to_not receive(:find_or_create_consumer)
          expect(links_manager).to_not receive(:find_or_create_consumer_intent)

          variable_spec = {
            'name' => 'bbs',
            'type' => 'certificate',
            'consumes' => {},
          }
          subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
        end
      end

      context 'when the variable is not of type certificate' do
        it 'should raise an error if it defines consumers' do
          expect(links_manager).to_not receive(:find_or_create_consumer)
          expect(links_manager).to_not receive(:find_or_create_consumer_intent)

          variable_spec = {
            'name' => 'bbs',
            'type' => 'foobar',
            'consumes' => {
              'alternative_name' => { 'from' => 'foo' },
            },
          }
          expect do
            subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
          end.to raise_error "Variable 'bbs' can not define 'consumes' key for type 'foobar'"
        end
      end

      context 'when the variable define non-acceptable consumers' do
        it 'should raise an error' do
          expect(links_manager).to_not receive(:find_or_create_consumer)
          expect(links_manager).to_not receive(:find_or_create_consumer_intent)

          variable_spec = {
            'name' => 'bbs',
            'type' => 'certificate',
            'consumes' => {
              'foobar' => { 'from' => 'foo' },
            },
          }
          expect do
            subject.parse_consumers_from_variable(variable_spec, deployment_plan.model)
          end.to raise_error "Consumer name 'foobar' is not a valid consumer for variable 'bbs'. Acceptable consumer types are:"\
          ' alternative_name, common_name'
        end
      end
    end
  end
end
