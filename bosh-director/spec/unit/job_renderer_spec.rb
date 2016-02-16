require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    subject(:renderer) { described_class.new(blobstore, logger) }
    let(:job) { DeploymentPlan::Job.new(logger) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    before do
      job.vm_type = DeploymentPlan::VmType.new({'name' => 'fake-vm-type'})
      job.stemcell = DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell-name', 'version' => '1.0'})
      job.env = DeploymentPlan::Env.new({})
    end

    let(:template_1) { DeploymentPlan::Template.new(release_version, 'fake-template-1') }
    let(:template_2) { DeploymentPlan::Template.new(release_version, 'fake-template-2') }
    let(:release_version) { DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'fake-release', 'version' => '123'}) }
    let(:deployment_model) { Models::Deployment.make(name: 'fake-deployment') }

    before { allow(Core::Templates::JobInstanceRenderer).to receive(:new).and_return(job_instance_renderer) }
    let(:job_instance_renderer) { instance_double('Bosh::Director::Core::Templates::JobInstanceRenderer') }

    before { allow(Core::Templates::JobTemplateLoader).to receive(:new).and_return(job_template_loader) }
    let(:job_template_loader) { instance_double('Bosh::Director::Core::Templates::JobTemplateLoader') }

    describe '#render_job_instances' do
      let(:instance_plan1) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }
      let(:instance_plan2) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }

      let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

      it 'renders each jobs instance' do
        expect(renderer).to receive(:render_job_instance).with(instance_plan1)
        expect(renderer).to receive(:render_job_instance).with(instance_plan2)
        renderer.render_job_instances([instance_plan1, instance_plan2])
      end
    end

    describe '#render_job_instance' do
      def perform
        renderer.render_job_instance(instance_plan)
      end

      let(:instance_plan) do
        DeploymentPlan::InstancePlan.new(existing_instance: instance_model, desired_instance: DeploymentPlan::DesiredInstance.new(job), instance: instance)
      end

      let(:instance) do
        deployment = instance_double(DeploymentPlan::Planner, model: deployment_model)
        availability_zone = DeploymentPlan::AvailabilityZone.new('z1', {})
        DeploymentPlan::Instance.create_from_job(job, 5, 'started', deployment, {}, availability_zone, logger)
      end

      before do
        allow(instance_plan).to receive_message_chain(:spec, :as_template_spec).and_return({'template' => 'spec'})
        allow(instance_plan).to receive(:templates).and_return([template_1, template_2])
        instance.bind_existing_instance_model(instance_model)
      end

      let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

      let(:instance_model) do
        Models::Instance.make(deployment: deployment_model)
      end

      before { allow(job_instance_renderer).to receive(:render).and_return(rendered_job_instance) }
      let(:rendered_job_instance) do
        instance_double('Bosh::Director::Core::Templates::RenderedJobInstance', {
          configuration_hash: configuration_hash,
          template_hashes: { 'job-template-name' => 'rendered-job-template-hash' },
          persist: rendered_templates_archive,
        })
      end

      let(:rendered_templates_archive) do
        instance_double('Bosh::Director::Core::Templates::RenderedTemplatesArchive', {
          blobstore_id: 'fake-new-blob-id',
          sha1: 'fake-new-sha1',
        })
      end

      let(:configuration_hash) { 'fake-content-sha1' }

      it 'correctly initializes JobInstanceRenderer' do
        expect(Core::Templates::JobInstanceRenderer).to receive(:new) do |templates, template_loader|
          expect(templates).to eq([template_1, template_2])
          expect(template_loader).to eq(job_template_loader)
        end.and_return(job_instance_renderer)
        perform
      end

      context 'when instance does not have a latest archive' do
        before { allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(nil) }

        it 'persists new archive' do
          expect(rendered_job_instance).to receive(:persist).with(blobstore)
          perform
        end

        it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
          expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)
          perform
        end

        it 'persists blob record in the database' do
          current_time = Time.now
          allow(Time).to receive(:now).and_return(current_time)

          expect(instance_model).to receive(:add_rendered_templates_archive).with(
            blobstore_id: 'fake-new-blob-id',
            sha1: 'fake-new-sha1',
            content_sha1: configuration_hash,
            created_at: current_time,
          )

          perform
        end
      end

      context 'when instance plan does not have templates' do
        before do
          allow(instance_plan).to receive(:templates).and_return([])
        end

        it 'does not render' do
          expect(job_instance_renderer).to_not receive(:render)
          perform
        end
      end

      context 'when instance has rendered job templates archives' do
        before { allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(latest_archive) }
        let(:latest_archive) do
          # Not using an instance double since Sequel Model classes are a bit meta
          double('Bosh::Directore::Models::RenderedTemplatesArchive', {
            instance: instance_model,
            blobstore_id: 'fake-latest-blob-id',
            sha1: 'fake-latest-sha1',
            content_sha1: 'fake-latest-content-sha1',
            created_at: Time.new(2013, 02, 01),
          })
        end

        before { allow(Core::Templates::RenderedTemplatesArchive).to receive(:new).and_return(latest_rendered_templates_archive) }
        let(:latest_rendered_templates_archive) do
          instance_double('Bosh::Director::Core::Templates::RenderedTemplatesArchive', {
            blobstore_id: 'fake-latest-blob-id',
            sha1: 'fake-latest-sha1',
          })
        end

        context 'when latest archive has matching content_sha1' do
          let(:configuration_hash) { 'fake-latest-content-sha1' }

          context 'when rendered template exists in blobstore' do
            before { allow(blobstore).to receive(:exists?).with('fake-latest-blob-id').and_return(true) }

            it 'does not persist new archive' do
              expect(rendered_job_instance).to_not receive(:persist)
              perform
            end

            it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
              expect(instance).to receive(:rendered_templates_archive=).with(latest_rendered_templates_archive)
              expect(Core::Templates::RenderedTemplatesArchive).to receive(:new).
                with('fake-latest-blob-id', 'fake-latest-sha1')
              perform
            end
          end

          context 'when rendered template is missing in blobstore' do
            before do
              allow(blobstore).to receive(:exists?).with('fake-latest-blob-id').and_return(false)
              allow(Core::Templates::RenderedTemplatesArchive).to receive(:new).and_return(latest_archive)
            end

            it 'uploads the new archive and updates the record in db' do
              expect(latest_archive).to receive(:update).with({:blobstore_id => 'fake-new-blob-id', :sha1 => 'fake-new-sha1'})
              expect(rendered_job_instance).to receive(:persist).with(blobstore)
              expect(instance).to receive(:rendered_templates_archive=).with(latest_archive)
              perform
            end
          end
        end

        context 'when latest archive does not have matching content_sha1' do
          let(:configuration_hash) { 'fake-latest-non-matching-content-sha1' }

          it 'persists new archive' do
            expect(rendered_job_instance).to receive(:persist).with(blobstore)
            perform
          end

          it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
            expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)
            perform
          end

          it 'persists blob record in the database' do
            current_time = Time.now
            allow(Time).to receive(:now).and_return(current_time)
            expect(instance_model).to receive(:add_rendered_templates_archive).with(
                blobstore_id: 'fake-new-blob-id',
                sha1: 'fake-new-sha1',
                content_sha1: configuration_hash,
                created_at: current_time,
              )
            perform
          end
        end
      end

      it 'renders all templates for all instances of a job' do
        expect(job_instance_renderer).to receive(:render).with({'template' => 'spec'})
        perform
      end

      it 'updates each instance with configuration and templates hashses' do
        expect(instance).to receive(:configuration_hash=).with(configuration_hash)
        expect(instance).to receive(:template_hashes=).with(rendered_job_instance.template_hashes)
        perform
      end

      it 'uploads all the rendered templates for instance that has configuration_hash' do
        expect(instance).to receive(:rendered_templates_archive=).with(rendered_templates_archive)
        expect(rendered_job_instance).to receive(:persist).with(blobstore)
        perform
      end
    end
  end
end
