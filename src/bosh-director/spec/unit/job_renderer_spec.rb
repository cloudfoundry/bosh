require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    let(:instance_group) do
      instance_group = DeploymentPlan::InstanceGroup.new(logger)
      instance_group.name = 'test-instance-group'
      instance_group
    end
    let(:blobstore_client) { instance_double(Bosh::Blobstore::BaseClient) }
    let(:blobstore_files) { [] }
    let(:cache) { Bosh::Director::Core::Templates::TemplateBlobCache.new }
    let(:encoder) { LocalDnsEncoderManager.new_encoder_with_updated_index([]) }

    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new(existing_instance: instance_model, desired_instance: DeploymentPlan::DesiredInstance.new(instance_group), instance: instance)
    end

    let(:instance) do
      deployment = instance_double(DeploymentPlan::Planner, model: deployment_model)
      availability_zone = DeploymentPlan::AvailabilityZone.new('z1', {})
      DeploymentPlan::Instance.create_from_job(instance_group, 5, 'started', deployment, {}, availability_zone, logger)
    end

    let(:deployment_model) { Models::Deployment.make(name: 'fake-deployment') }
    let(:instance_model) { Models::Instance.make(deployment: deployment_model) }

    before do
      job_tgz_path = asset('dummy_job_with_single_template.tgz')
      allow(blobstore_client).to receive(:get) { |_, f| blobstore_files << f.path; f.write(File.read(job_tgz_path)) }
      allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
    end

    describe '#render_job_instances_with_cache' do
      def perform
        JobRenderer.render_job_instances_with_cache([instance_plan], cache, encoder, logger)
      end

      before do
        release_version = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'fake-release', 'version' => '123'})
        job_1 = DeploymentPlan::Job.new(release_version, 'dummy', deployment_model.name)
        job_1.bind_existing_model(Models::Template.make(blobstore_id: 'my-blobstore-id'))

        job_2 = DeploymentPlan::Job.new(release_version, 'dummy', deployment_model.name)
        job_2.bind_existing_model(Models::Template.make(blobstore_id: 'my-blobstore-id'))

        allow(instance_plan).to receive_message_chain(:spec, :as_template_spec).and_return({'template' => 'spec'})
        allow(instance_plan).to receive(:templates).and_return([job_1, job_2])
      end

      context 'when instance plan does not have templates' do
        before do
          allow(instance_plan).to receive(:templates).and_return([])
        end

        it 'does not render' do
          expect(logger).to receive(:debug).with("Skipping rendering templates for 'test-instance-group/5', no templates")
          expect { perform }.not_to change { instance_plan.rendered_templates }
        end
      end

      context 'when instance plan has templates' do
        it 'renders all templates for all instances of a instance_group' do
          expect(instance_plan.rendered_templates).to be_nil
          expect(instance.configuration_hash).to be_nil
          expect(instance.template_hashes).to be_nil

          perform

          expect(instance_plan.rendered_templates.template_hashes.keys).to eq ['dummy']
          expect(instance.configuration_hash).to eq('8c0d7fac26d36e3b51de2d43f17302b4c04fa377')
          expect(instance.template_hashes.keys).to eq(['dummy'])
        end

        context 'when a template has already been downloaded' do
          it 'should reuse the downloaded template' do
            perform

            expect(blobstore_client).to have_received(:get).once
          end
        end
      end

      context 'when getting the templates spec of an instance plan errors' do
        before do
          allow(instance).to receive(:job_name).and_return('my_instance_group')
          allow(instance_plan).to receive_message_chain(:spec, :as_template_spec).and_raise Exception, <<-EOF
- Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
- Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
          EOF
        end

        it 'formats the error messages' do
          expected = <<-EXPECTED.strip
- Unable to render jobs for instance group 'my_instance_group'. Errors are:
  - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
  - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
          EXPECTED

          expect {
            perform
          }.to raise_error { |error|
            expect(error.message).to eq(expected)
          }
        end
      end
    end
  end
end
