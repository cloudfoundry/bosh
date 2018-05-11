require 'spec_helper'

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

    release_spec = {properties: {}}
    release_spec[:properties] = properties if properties
    release_spec[:consumes] = consumes if consumes
    release_spec[:provides] = provides if provides

    # This is creating a job
    release_version_model.add_template(
      Bosh::Director::Models::Template.make(
        name: "#{release_name}_job_name_1",
        release: release_model,
        spec: release_spec
      )
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
    create_release("release1", '1', provides: release_providers, consumes: release_consumers, properties: release_properties)
  end

  let(:template) do
    release.templates.first
  end

  let(:release_providers) {nil}
  let(:release_consumers) {nil}
  let(:release_properties) {nil}

  describe '#parse_migrated_from_providers_from_job' do
    let(:provider) {instance_double(Bosh::Director::Models::Links::LinkProvider)}
    let(:provider_intent) {instance_double(Bosh::Director::Models::Links::LinkProviderIntent)}

    let(:job_properties) {{}}

    let(:release_providers) do
      [{name: 'link_1_name', type: 'link_1_type'}]
    end

    let(:job_spec) do
      {
        'name' => 'jobby1',
        'release' => 'release1',
        'provides' => {
          'link_1_name' => {
            'as' => 'link_1_name_alias',
            'shared' => true,
            'properties' => {},
          }
        }
      }
    end

    context 'when the job belongs to an instance group that is being migrated' do
      let(:release_providers) do
        [
          {
            name: 'chocolate',
            type: 'flavour'
          }
        ]
      end

      let(:deployment_model) {BD::Models::Deployment.make(links_serial_id: serial_id)}
      let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner)}
      let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment_model) }
      let(:serial_id) { 1 }
      let!(:provider_1) do
        Bosh::Director::Models::Links::LinkProvider.make(
          deployment: deployment_model,
          instance_group: 'old-ig1',
          name: 'foobar',
          type: 'job',
          serial_id: serial_id
        )
      end

      let!(:provider_1_intent) do
        Bosh::Director::Models::Links::LinkProviderIntent.make(
          :link_provider => provider_1,
          :original_name => 'chocolate',
          :name => 'chocolate',
          :type => 'flavour',
          :shared => true,
          :consumable => true,
          :content => '{}',
          :serial_id => serial_id
        )
      end

      let(:link_providers) do
        [provider_1]
      end

      let(:job_spec) do
        {
          'name' => 'foobar',
          'release' => 'release1',
          'properties' => job_properties,
          'provides' => {
            'chocolate' => {
              'as' => 'chocolate'
            }
          }
        }
      end

      let(:job_properties) do
        {
          'street' => 'Any Street',
        }
      end

      let(:migrated_from) do
        [
          {'name' => 'old_ig1', 'az' => 'az1'},
          {'name' => 'old_ig2', 'az' => 'az2'}
        ]
      end

      before do
        allow(deployment_model).to receive(:link_providers).and_return(link_providers)
      end

      it 'should update the instance_group name to match the existing provider' do
        expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig1',
          name: 'foobar',
          type: 'job'
        ).and_return(provider_1)
        expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig2',
          name: 'foobar',
          type: 'job'
        ).and_return(nil)
        expect(links_manager).to receive(:find_or_create_provider).with(deployment_model: deployment_model, instance_group_name: "old_ig1",name: "foobar",type: "job").and_return(provider_1)
        expect(links_manager).to receive(:find_or_create_provider_intent).with(link_provider: provider_1, link_original_name: 'chocolate', link_type: 'flavour').and_return(provider_1_intent)
        subject.parse_migrated_from_providers_from_job(job_spec, deployment_model, template, job_properties, "new-ig", migrated_from)
      end
    end

    context 'when there is a new job during a migrated_from deploy' do
      let(:migrated_from) do
        [
          {'name' => 'old_ig1', 'az' => 'az1'},
          {'name' => 'old_ig2', 'az' => 'az2'}
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
          name: 'jobby1',
          type: 'job'
        ).and_return(nil)
        expect(Bosh::Director::Models::Links::LinkProvider).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig2',
          name: 'jobby1',
          type: 'job'
        ).and_return(nil)
        expect(links_manager).to receive(:find_or_create_provider).with(deployment_model: deployment_model, instance_group_name: "instance-group-name",name: "jobby1",type: "job").and_return(provider)
        expect(links_manager).to receive(:find_or_create_provider_intent).with(link_provider: provider, link_original_name: 'link_1_name', link_type: 'link_1_type').and_return(provider_intent)

        subject.parse_migrated_from_providers_from_job(job_spec, deployment_plan.model, template, job_properties, "instance-group-name", migrated_from)
      end
    end
  end

  describe '#parse_migrated_from_consumers_from_job' do
    let(:consumer) {instance_double(Bosh::Director::Models::Links::LinkConsumer)}
    let(:consumer_intent) {instance_double(Bosh::Director::Models::Links::LinkConsumerIntent)}

    let(:job_properties) {{}}

    let(:release_consumers) do
      [{name: 'link_1_name', type: 'link_1_type'}]
    end

    let(:job_spec) do
      {
        'name' => 'jobby1',
        'release' => 'release1',
        'consumes' => {
          'link_1_name' => {
            'from' => 'link_1_name_alias',
          }
        }
      }
    end

    context 'when the job belongs to an instance group that is being migrated' do
      let(:release_consumers) do
        [
          {
            name: 'chocolate',
            type: 'flavour'
          }
        ]
      end

      let(:deployment_model) {BD::Models::Deployment.make(links_serial_id: serial_id)}
      let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner)}
      let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment_model) }
      let(:serial_id) { 1 }
      let!(:consumer) do
        Bosh::Director::Models::Links::LinkConsumer.make(
          deployment: deployment_model,
          instance_group: 'old-ig1',
          name: 'foobar',
          type: 'job',
          serial_id: serial_id
        )
      end

      let!(:consumer_intent) do
        Bosh::Director::Models::Links::LinkConsumerIntent.make(
          :link_consumer => consumer,
          :original_name => 'chocolate',
          :name => 'chocolate',
          :type => 'flavour',
          :blocked => false,
          :serial_id => serial_id
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
              'from' => 'chocolate'
            }
          }
        }
      end

      let(:migrated_from) do
        [
          {'name' => 'old_ig1', 'az' => 'az1'},
          {'name' => 'old_ig2', 'az' => 'az2'}
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
          type: 'job'
        ).and_return(consumer)
        expect(Bosh::Director::Models::Links::LinkConsumer).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig2',
          name: 'foobar',
          type: 'job'
        ).and_return(nil)
        expect(links_manager).to receive(:find_or_create_consumer).with(deployment_model: deployment_model, instance_group_name: "old_ig1",name: "foobar",type: "job").and_return(consumer)
        expect(links_manager).to receive(:find_or_create_consumer_intent).with(link_consumer: consumer, link_original_name: 'chocolate', link_type: 'flavour', new_intent_metadata: nil).and_return(consumer_intent)
        subject.parse_migrated_from_consumers_from_job(job_spec, deployment_model, template, "new-ig", migrated_from)
      end
    end

    context 'when there is a new job during a migrated_from deploy' do
      let(:migrated_from) do
        [
          {'name' => 'old_ig1', 'az' => 'az1'},
          {'name' => 'old_ig2', 'az' => 'az2'}
        ]
      end

      before do
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
          name: 'jobby1',
          type: 'job'
        ).and_return(nil)
        expect(Bosh::Director::Models::Links::LinkConsumer).to receive(:find).with(
          deployment: deployment_model,
          instance_group: 'old_ig2',
          name: 'jobby1',
          type: 'job'
        ).and_return(nil)
        expect(links_manager).to receive(:find_or_create_consumer).with(deployment_model: deployment_model, instance_group_name: "instance-group-name",name: "jobby1",type: "job").and_return(consumer)
        expect(links_manager).to receive(:find_or_create_consumer_intent).with(link_consumer: consumer, link_original_name: 'link_1_name', link_type: 'link_1_type',  new_intent_metadata: nil).and_return(consumer_intent)

        subject.parse_migrated_from_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name", migrated_from)
      end
    end
  end

  describe '#parse_providers_from_job' do
    let(:provider) {instance_double(Bosh::Director::Models::Links::LinkProvider)}
    let(:provider_intent) {instance_double(Bosh::Director::Models::Links::LinkProviderIntent)}

    let(:job_properties) {{}}

    context 'when the job does NOT define any provider in its release spec' do
      context 'when the manifest specifies provided links for that job' do
        let(:job_spec) do
          {
            'name' => 'job_1',
            'provides' => {'foo' => {}}
          }
        end

        it 'raise an error' do
          expect {
            subject.parse_providers_from_job(job_spec, deployment_plan.model, template, {}, "instance-group-name")
          }.to raise_error "Job 'job_1' in instance group 'instance-group-name' specifies providers in the manifest but the job does not define any providers in the release spec"
        end
      end

      context 'when the manifest does not specify any providers' do
        let(:job_spec) do
          {
            'name' => 'job_1'
          }
        end

        it 'should not create any provider and intents' do
          expect(links_manager).to_not receive(:find_or_create_provider)
          expect(links_manager).to_not receive(:find_or_create_provider_intent)

          subject.parse_providers_from_job(job_spec, deployment_plan.model, template, {}, "instance-group-name")
        end
      end
    end

    context 'when a job defines a provider in its release spec' do
      let(:release_providers) do
        [{name: 'link_1_name', type: 'link_1_type'}]
      end

      context 'when the job exposes properties in the provided link' do
        let(:release_properties) do
          {
            'street' => {'default' => 'Any Street'},
            'scope' => {},
            'division.router' => {'default' => 'Canada'},
            'division.priority' => {'default' => 'NOW!'},
            'division.sequence' => {},
          }
        end

        let(:release_providers) do
          [
            {
              name: 'link_1_name',
              type: 'link_1_type',
              properties:
                ['street', 'scope', 'division.priority', 'division.sequence']
            }
          ]
        end

        let(:job_spec) do
          {
            'name' => 'job-name1',
            'release' => 'release1',
            'properties' => job_properties
          }
        end

        let(:job_properties) do
          {
            'street' => 'Any Street',
            'division' => {
              'priority' => 'LOW',
              'sequence' => 'FIFO'
            }
          }
        end

        it 'should update the provider intent metadata with the correct mapped properties' do
          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'job-name1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type'
          }
          expect(links_manager).to receive(:find_or_create_provider_intent).with(expected_provider_intent_params).and_return(provider_intent)

          mapped_properties = {
            'street' => 'Any Street',
            'scope' => nil,
            'division' => {
              'priority' => 'LOW',
              'sequence' => 'FIFO',
            }
          }

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:metadata=).with({:mapped_properties => mapped_properties}.to_json)
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)
          subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, "instance-group-name")
        end

        context 'when the exposed property is not defined in the release' do
          let(:release_properties) do
            {
              'street' => {'default' => 'Any Street'},
              'division.router' => {'default' => 'Canada'},
              'division.priority' => {'default' => 'NOW!'},
              'division.sequence' => {},
            }
          end

          let(:job_properties) do
            {
              'street' => 'Any Street',
              'division' => {
                'priority' => 'LOW',
                'sequence' => 'FIFO'
              }
            }
          end

          it 'raise an error' do
            expected_provider_params = {
              deployment_model: deployment_plan.model,
              instance_group_name: 'instance-group-name',
              name: 'job-name1',
              type: 'job',
            }

            expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)
            expect(links_manager).to_not receive(:find_or_create_provider_intent)
            expect(provider_intent).to_not receive(:metadata=)
            expect(provider_intent).to_not receive(:shared=)
            expect(provider_intent).to_not receive(:name=)
            expect(provider_intent).to_not receive(:save)

            expect {
              subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
            }.to raise_error(RuntimeError, 'Link property scope in template release1_job_name_1 is not defined in release spec')
          end
        end
      end

      context 'when a job does NOT define a provides section in manifest' do
        let(:job_spec) do
          {
            'name' => 'job-name1',
            'release' => 'release1'
          }
        end

        it 'should add correct link providers and link providers intent to the DB' do
          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: "instance-group-name",
            name: 'job-name1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type'
          }
          expect(links_manager).to receive(:find_or_create_provider_intent).with(expected_provider_intent_params).and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:metadata=).with({'mapped_properties' => {}}.to_json)
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)

          subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, "instance-group-name")
        end
      end

      context 'when a job defines a provides section in manifest' do
        let(:job_spec) do
          {
            'name' => 'job-name1',
            'release' => 'release1',
            'provides' => {
              'link_1_name' => {
                'as' => 'link_1_name_alias',
                'shared' => true,
              }
            }
          }
        end

        let(:job_properties) {{}}

        it 'should add correct link providers and link providers intent to the DB' do
          original_job_spec = Bosh::Common::DeepCopy.copy(job_spec)

          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: "instance-group-name",
            name: 'job-name1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type'
          }
          expect(links_manager).to receive(:find_or_create_provider_intent).with(expected_provider_intent_params).and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name_alias')
          expect(provider_intent).to receive(:metadata=).with({'mapped_properties' => {}}.to_json)
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:shared=).with(true)
          expect(provider_intent).to receive(:save)
          subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, "instance-group-name")
          expect(job_spec).to eq(original_job_spec)
        end
      end

      context 'when a job defines a nil provides section in the manifest' do
        let(:job_spec) do
          {
            'name' => 'job-name1',
            'release' => 'release1',
            'provides' => {
              'link_1_name' => 'nil'
            }
          }
        end

        it 'should set the intent consumable to false' do
          expected_provider_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'job-name1',
            type: 'job',
          }
          expect(links_manager).to receive(:find_or_create_provider).with(expected_provider_params).and_return(provider)

          expected_provider_intent_params = {
            link_provider: provider,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type'
          }
          expect(links_manager).to receive(:find_or_create_provider_intent).with(expected_provider_intent_params).and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:metadata=).with({'mapped_properties' => {}}.to_json)
          expect(provider_intent).to receive(:consumable=).with(false)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)
          subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
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
              'name' => 'job-name1',
              'release' => 'release1',
              'provides' => {
                'link_1_name' => {
                  'name' => 'better_link_1_name',
                  'shared' => true,
                }
              }
            }

            expect {
              subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
            }.to raise_error(RuntimeError, "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'. Please provide these keys in the release only.")
          end

          it 'should fail if there is a type' do
            job_spec = {
              'name' => 'job-name1',
              'release' => 'release1',
              'provides' => {
                'link_1_name' => {
                  'type' => 'better_link_1_type',
                  'shared' => true,
                }
              }
            }

            expect {
              subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
            }.to raise_error(RuntimeError, "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'. Please provide these keys in the release only.")
          end
        end

        context 'when the provides section is not a hash' do
          it "raise an error" do
            job_spec = {
              'name' => 'job-name1',
              'release' => 'release1',
              'provides' => {
                'link_1_name' => ['invalid stuff']
              }
            }

            expect {
              subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
            }.to raise_error(RuntimeError, "Provider 'link_1_name' in job 'job-name1' in instance group 'instance-group-name' specified in the manifest should only be a hash or string 'nil'")
          end

          context "when it is a string that is not 'nil'" do
            it "raise an error" do
              job_spec = {
                'name' => 'job-name1',
                'release' => 'release1',
                'provides' => {
                  'link_1_name' => 'invalid stuff'
                }
              }

              expect {
                subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
              }.to raise_error(RuntimeError, "Provider 'link_1_name' in job 'job-name1' in instance group 'instance-group-name' specified in the manifest should only be a hash or string 'nil'")
            end
          end
        end
      end

      context 'when a manifest job defines a provider which is not specified in the release' do
        it 'should fail because it does not match the release' do
          job_spec = {
            'name' => 'job-name1',
            'release' => 'release1',
            'provides' => {
              'new_link_name' => {
                'shared' => 'false',
              }
            }
          }

          expect(links_manager).to receive(:find_or_create_provider).and_return(provider)

          expect(links_manager).to receive(:find_or_create_provider_intent).and_return(provider_intent)

          expect(provider_intent).to receive(:name=).with('link_1_name')
          expect(provider_intent).to receive(:consumable=).with(true)
          expect(provider_intent).to receive(:metadata=).with({'mapped_properties' => {}}.to_json)
          expect(provider_intent).to receive(:shared=).with(false)
          expect(provider_intent).to receive(:save)
          expect {
            subject.parse_providers_from_job(job_spec, deployment_plan.model, template, job_properties, 'instance-group-name')
          }.to raise_error(RuntimeError, "Manifest defines unknown providers:\n  - Job 'job-name1' does not provide link 'new_link_name' in the release spec")
        end
      end
    end
  end

  describe '#parse_consumers_from_job' do
    let(:consumer) {instance_double(Bosh::Director::Models::Links::LinkConsumer)}
    let(:consumer_intent) {instance_double(Bosh::Director::Models::Links::LinkConsumerIntent)}

    context 'when the job does NOT define any consumer in its release spec' do
      it 'should raise an error when the manifest has consumer specified' do
        job_spec = {
          'name' => 'job-name1',
          'release' => 'release1',
          'consumes' => {
            'undefined_link_consumer' => {}
          }
        }

        expect {
          subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
        }.to raise_error("Job 'job-name1' in instance group 'instance-group-name' specifies consumers in the manifest but the job does not define any consumers in the release spec")
      end

      context 'when the manifest does not specify any providers' do
        let(:job_spec) do
          {
            'name' => 'job_1'
          }
        end

        it 'should not create any provider and intents' do
          expect(links_manager).to_not receive(:find_or_create_consumer)
          expect(links_manager).to_not receive(:find_or_create_consumer_intent)

          subject.parse_providers_from_job(job_spec, deployment_plan.model, template, {}, "instance-group-name")
        end
      end
    end

    context 'when a job defines a consumer in its release spec' do
      context 'when consumer is implicit (not specified in the deployment manifest)' do
        let(:release_consumers) do
          [
            {name: 'link_1_name', type: 'link_1_type'}
          ]
        end

        let(:job_spec) do
          {
            'name' => 'job-name1',
            'release' => 'release1'
          }
        end

        it 'should add the consumer and consumer intent to the DB' do
          expected_consumer_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'job-name1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_consumer).with(expected_consumer_params).and_return(consumer)

          expected_consumer_intent_params = {
            link_consumer: consumer,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
            new_intent_metadata: nil
          }

          expect(links_manager).to receive(:find_or_create_consumer_intent).with(expected_consumer_intent_params).and_return(consumer_intent)

          expect(consumer_intent).to receive(:name=).with('link_1_name')
          expect(consumer_intent).to receive(:blocked=).with(false)
          expect(consumer_intent).to receive(:optional=).with(false)
          expect(consumer_intent).to receive(:metadata=).with({:explicit_link => false}.to_json)
          expect(consumer_intent).to receive(:save)

          subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
        end

        context 'when the release spec defines the link as optional' do
          let(:release_consumers) do
            [
              {name: 'link_1_name', type: 'link_1_type', optional: true}
            ]
          end

          it 'sets consumer intent optional field to true' do
            expect(links_manager).to receive(:find_or_create_consumer).and_return(consumer)
            expect(links_manager).to receive(:find_or_create_consumer_intent).and_return(consumer_intent)

            expect(consumer_intent).to receive(:metadata=).with({:explicit_link => false}.to_json)
            expect(consumer_intent).to receive(:name=).with('link_1_name')
            expect(consumer_intent).to receive(:blocked=).with(false)
            expect(consumer_intent).to receive(:optional=).with(true)
            expect(consumer_intent).to receive(:save)

            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end
        end
      end

      context 'when consumer is explicit (specified in the deployment manifest)' do
        let(:release_consumers) do
          [{name: 'link_1_name', type: 'link_1_type'}]
        end
        let(:consumer_options) {{'from' => 'snoopy'}}
        let(:manifest_link_consumers) {{'link_1_name' => consumer_options}}
        let(:job_spec) do
          {
            'name' => 'job-name1',
            'release' => 'release1',
            'consumes' => manifest_link_consumers
          }
        end

        before do
          allow(links_manager).to receive(:find_or_create_consumer).and_return(consumer)
          allow(links_manager).to receive(:find_or_create_consumer_intent).and_return(consumer_intent)
        end

        it 'should add the consumer and consumer intent to the DB' do
          original_job_spec = Bosh::Common::DeepCopy.copy(job_spec)

          expected_consumer_params = {
            deployment_model: deployment_plan.model,
            instance_group_name: 'instance-group-name',
            name: 'job-name1',
            type: 'job',
          }

          expect(links_manager).to receive(:find_or_create_consumer).with(expected_consumer_params).and_return(consumer)

          expected_consumer_intent_params = {
            link_consumer: consumer,
            link_original_name: 'link_1_name',
            link_type: 'link_1_type',
            new_intent_metadata: nil
          }

          expect(links_manager).to receive(:find_or_create_consumer_intent).with(expected_consumer_intent_params).and_return(consumer_intent)

          expect(consumer_intent).to receive(:name=).with('snoopy')
          expect(consumer_intent).to receive(:blocked=).with(false)
          expect(consumer_intent).to receive(:metadata=).with({:explicit_link => true}.to_json)
          expect(consumer_intent).to receive(:optional=).with(false)
          expect(consumer_intent).to receive(:save)

          subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          expect(job_spec).to eq(original_job_spec)
        end

        context 'when the consumer alias is separated by "."' do
          let(:consumer_options) {{'from' => 'foo.bar.baz'}}

          before do
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:metadata=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          it 'should use the last segment in "from" as the alias' do
            expect(consumer_intent).to receive(:name=).with('baz')
            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end
        end

        context 'when the consumer is explicitly set to nil' do
          let(:consumer_options) {"nil"}

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:metadata=)
            allow(consumer_intent).to receive(:save)
          end

          it 'should set the consumer intent blocked' do
            expect(consumer_intent).to receive(:blocked=).with(true)

            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end
        end

        context 'when the consumer does not have a from key' do
          let(:consumer_options) {{}}

          before do
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:metadata=)
            allow(consumer_intent).to receive(:save)
          end

          it 'should set the consumer intent name to original name' do
            expect(consumer_intent).to receive(:name=).with('link_1_name')

            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end
        end

        context 'when the consumer specifies a specific network' do
          let(:consumer_options) {{'network' => 'charlie'}}

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          it 'will add specified network name to the metadata' do
            allow(consumer_intent).to receive(:metadata=).with({explicit_link: true, network: 'charlie'}.to_json)
            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end
        end

        context 'when the consumer specifies to use ip addresses only' do
          let(:consumer_options) {{'ip_addresses' => true}}

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
          end

          it 'will set the ip_addresses flag in the metadata to true' do
            allow(consumer_intent).to receive(:metadata=).with({explicit_link: true, ip_addresses: true}.to_json)
            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end
        end

        context 'when the consumer specifies to use a deployment' do
          let(:consumer_options) {{'deployment' => 'some-other-deployment'}}

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
              allow(consumer_intent).to receive(:metadata=).with({explicit_link: true, from_deployment: 'some-other-deployment'}.to_json)
              subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
            end
          end

          context 'when the provider deployment exists' do
            it 'raise an error' do
              expect {
                subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
              }.to raise_error "Link 'link_1_name' in job 'job-name1' from instance group 'instance-group-name' consumes from deployment 'some-other-deployment', but the deployment does not exist."
            end
          end
        end

        context 'when the consumer specifies the name key in the consumes section of the manifest' do
          let(:consumer_options) {{'name' => 'i should not be here'}}

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
            allow(consumer_intent).to receive(:metadata=)
          end

          it 'raise an error' do
            expect {subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")}.to raise_error "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'. Please provide these keys in the release only."
          end
        end

        context 'when the consumer specifies the type key in the consumes section of the manifest' do
          let(:consumer_options) {{'type' => 'i should not be here'}}

          before do
            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:save)
            allow(consumer_intent).to receive(:metadata=)
          end

          it 'raise an error' do
            expect {subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")}.to raise_error "Cannot specify 'name' or 'type' properties in the manifest for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'. Please provide these keys in the release only."
          end
        end

        context 'when processing manual links' do
          let(:manual_provider) {instance_double(Bosh::Director::Models::Links::LinkProvider)}
          let(:manual_provider_intent) {instance_double(Bosh::Director::Models::Links::LinkProviderIntent)}
          let(:consumer_options) do
            {
              'instances' => 'instances definition',
              'properties' => 'property definitions',
              'address' => 'address definition'
            }
          end

          before do
            allow(deployment_model).to receive(:name).and_return('charlie')

            allow(consumer_intent).to receive(:name=)
            allow(consumer_intent).to receive(:blocked=)
            allow(consumer_intent).to receive(:optional=)
            allow(consumer_intent).to receive(:metadata=)
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

            expect(consumer_intent).to receive(:metadata=).with({explicit_link: true, manual_link: true}.to_json)

            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end

          it 'creates a manual provider in the database' do
            allow(links_manager).to receive(:find_or_create_provider_intent).and_return(manual_provider_intent)

            expect(links_manager).to receive(:find_or_create_provider).with(
              deployment_model: deployment_model,
              instance_group_name: 'consumer_instance_group',
              name: 'consumer_name',
              type: 'manual'
            ).and_return(manual_provider)

            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end

          it 'creates a manual provider intent in the database' do
            allow(links_manager).to receive(:find_or_create_provider).and_return(manual_provider)

            expect(links_manager).to receive(:find_or_create_provider_intent).with(
              link_provider: manual_provider,
              link_original_name: 'link_1_name',
              link_type: 'link_1_type'
            ).and_return(manual_provider_intent)

            expected_content = {
              'instances' => 'instances definition',
              'properties' => 'property definitions',
              'address' => 'address definition',
              'deployment_name' => 'charlie'
            }

            expect(manual_provider_intent).to receive(:name=).with('link_1_name')
            expect(manual_provider_intent).to receive(:content=).with(expected_content.to_json)

            subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
          end

          context 'when the manual link has keys that are not whitelisted' do
            let(:consumer_options) do
              {
                'instances' => 'instances definition',
                'properties' => 'property definitions',
                'address' => 'address definition',
                'foo' => 'bar',
                'baz' => 'boo'
              }
            end

            it 'should only add whitelisted values' do
              allow(links_manager).to receive(:find_or_create_provider).and_return(manual_provider)

              expect(links_manager).to receive(:find_or_create_provider_intent).with(
                link_provider: manual_provider,
                link_original_name: 'link_1_name',
                link_type: 'link_1_type'
              ).and_return(manual_provider_intent)

              expected_content = {
                'instances' => 'instances definition',
                'properties' => 'property definitions',
                'address' => 'address definition',
                'deployment_name' => 'charlie'
              }

              expect(manual_provider_intent).to receive(:content=).with(expected_content.to_json)

              subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
            end
          end
        end

        context 'consumer validation' do
          context "when 'instances' and 'from' keywords are specified at the same time" do
            let(:consumer_options) {{'from' => 'snoopy', 'instances' => ['1.2.3.4']}}

            it 'should raise an error' do
              expect {
                subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
              }.to raise_error(/Cannot specify both 'instances' and 'from' keys for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'./)
            end
          end

          context "when 'properties' and 'from' keywords are specified at the same time" do
            let(:consumer_options) {{'from' => 'snoopy', 'properties' => {'meow' => 'cat'}}}

            it 'should raise an error' do
              expect {
                subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
              }.to raise_error(/Cannot specify both 'properties' and 'from' keys for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'./)
            end
          end

          context "when 'properties' is defined but 'instances' is not" do
            let(:consumer_options) {{'properties' => 'snoopy'}}

            it 'should raise an error' do
              expect {
                subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
              }.to raise_error(/Cannot specify 'properties' without 'instances' for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'./)
            end
          end

          context "when 'ip_addresses' value is not a boolean" do
            let(:consumer_options) {{'ip_addresses' => 'not a boolean'}}

            it 'should raise an error' do
              expect {
                subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
              }.to raise_error(/Cannot specify non boolean values for 'ip_addresses' field for link 'link_1_name' in job 'job-name1' in instance group 'instance-group-name'./)
            end
          end

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
                " - Job 'job-name1' does not define consumer 'first_undefined' in the release spec",
                " - Job 'job-name1' does not define consumer 'second_undefined' in the release spec"
              ].join("\n")

              expect {
                subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
              }.to raise_error(expected_error)
            end
          end

          context 'when the manifest specifies consumers that are not hashes or "nil" string' do
            context 'consumer is an array' do
              let(:consumer_options) {['Unaccepted type array']}

              it 'should raise an error' do
                expect {
                  subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
                }.to raise_error "Consumer 'link_1_name' in job 'job-name1' in instance group 'instance-group-name' specified in the manifest should only be a hash or string 'nil'"
              end
            end

            context 'consumer is a string that is not "nil"' do
              let(:consumer_options) {'Unaccepted string value'}

              it 'should raise an error' do
                expect {
                  subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
                }.to raise_error "Consumer 'link_1_name' in job 'job-name1' in instance group 'instance-group-name' specified in the manifest should only be a hash or string 'nil'"
              end
            end

            context 'consumer is empty or set to null' do
              let(:consumer_options) {nil}

              it 'should raise an error' do
                expect {
                  subject.parse_consumers_from_job(job_spec, deployment_plan.model, template, "instance-group-name")
                }.to raise_error "Consumer 'link_1_name' in job 'job-name1' in instance group 'instance-group-name' specified in the manifest should only be a hash or string 'nil'"
              end
            end
          end
        end
      end
    end
  end

  describe '#parse_provider_from_disk' do
    let(:provider) {instance_double(Bosh::Director::Models::Links::LinkProvider)}
    let(:provider_intent) {instance_double(Bosh::Director::Models::Links::LinkProviderIntent)}

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
        expect(links_manager).to receive(:find_or_create_provider_intent).with(expected_provider_intent_params).and_return(provider_intent)
        expect(provider_intent).to receive(:shared=)
        expect(provider_intent).to receive(:name=).with('my-disk')
        expect(provider_intent).to receive(:content=)
        expect(provider_intent).to receive(:save)
        #  expect not to raise an error
        disk_spec = {'name' => 'my-disk', 'type' => 'disk-type-small'}
        subject.parse_provider_from_disk(disk_spec, deployment_plan.model, "instance-group-name")
      end
    end
  end
end