require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    subject(:renderer) { described_class.new(job, blobstore) }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    before { allow(job).to receive(:templates).with(no_args).and_return(templates) }
    let(:templates) { [instance_double('Bosh::Director::DeploymentPlan::Template')] }

    before { allow(Core::Templates::JobInstanceRenderer).to receive(:new).and_return(job_instance_renderer) }
    let(:job_instance_renderer) { instance_double('Bosh::Director::Core::Templates::JobInstanceRenderer') }

    before { allow(Core::Templates::JobTemplateLoader).to receive(:new).and_return(job_template_loader) }
    let(:job_template_loader) { instance_double('Bosh::Director::Core::Templates::JobTemplateLoader') }

    describe '#render_job_instances' do
      before { allow(job).to receive(:instances).with(no_args).and_return([instance1, instance2]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

      let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

      it 'renders each jobs instance' do
        expect(renderer).to receive(:render_job_instance).with(instance1)
        expect(renderer).to receive(:render_job_instance).with(instance2)
        renderer.render_job_instances
      end
    end

    describe '#render_job_instance' do
      def perform
        renderer.render_job_instance(instance)
      end

      let(:instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance', {
          :configuration_hash= => nil,
          :template_hashes= => nil,
          :rendered_templates_archive= => nil,
          :model => instance_model,
          :spec => {},
        })
      end

      let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

      let(:instance_model) do
        # not using an instance double since Sequel Model classes are a bit meta
        double('Bosh::Director::Models::Instance', {
          add_rendered_templates_archive: true,
          latest_rendered_templates_archive: nil,
        })
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
        perform
        expect(Core::Templates::JobInstanceRenderer).to have_received(:new).
          with(templates, job_template_loader)
      end

      context 'when instance does not have a latest archive' do
        before { allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(nil) }

        it 'persists new archive' do
          perform
          expect(rendered_job_instance).to have_received(:persist).with(blobstore)
        end

        it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
          perform
          expect(instance).to have_received(:rendered_templates_archive=).with(rendered_templates_archive)
        end

        it 'persists blob record in the database' do
          current_time = Time.now
          allow(Time).to receive(:now).and_return(current_time)

          perform
          expect(instance_model).to have_received(:add_rendered_templates_archive).with(
            blobstore_id: 'fake-new-blob-id',
            sha1: 'fake-new-sha1',
            content_sha1: configuration_hash,
            created_at: current_time,
          )
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
              perform
              expect(rendered_job_instance).to_not have_received(:persist)
            end

            it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
              perform
              expect(Core::Templates::RenderedTemplatesArchive).to have_received(:new).
                with('fake-latest-blob-id', 'fake-latest-sha1')
              expect(instance).to have_received(:rendered_templates_archive=).with(latest_rendered_templates_archive)
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
            perform
            expect(rendered_job_instance).to have_received(:persist).with(blobstore)
          end

          it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
            perform
            expect(instance).to have_received(:rendered_templates_archive=).with(rendered_templates_archive)
          end

          it 'persists blob record in the database' do
            current_time = Time.now
            allow(Time).to receive(:now).and_return(current_time)

            perform
            expect(instance_model).to have_received(:add_rendered_templates_archive).with(
              blobstore_id: 'fake-new-blob-id',
              sha1: 'fake-new-sha1',
              content_sha1: configuration_hash,
              created_at: current_time,
            )
          end
        end
      end

      it 'renders all templates for all instances of a job' do
        perform
        expect(job_instance_renderer).to have_received(:render).with(instance.spec)
      end

      it 'updates each instance with configuration and templates hashses' do
        perform
        expect(instance).to have_received(:configuration_hash=).with(configuration_hash)
        expect(instance).to have_received(:template_hashes=).with(rendered_job_instance.template_hashes)
      end

      it 'uploads all the rendered templates for instance that has configuration_hash' do
        perform
        expect(instance).to have_received(:rendered_templates_archive=).with(rendered_templates_archive)
        expect(rendered_job_instance).to have_received(:persist).with(blobstore)
      end
    end
  end
end
