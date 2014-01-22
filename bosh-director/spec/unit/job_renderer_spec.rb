require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    subject(:renderer) { JobRenderer.new(job) }
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }

    before { JobInstanceRenderer.stub(:new).with(job, job_template_loader).and_return(job_instance_renderer) }
    let(:job_instance_renderer) { instance_double('Bosh::Director::JobInstanceRenderer') }

    before { JobTemplateLoader.stub(new: job_template_loader) }
    let(:job_template_loader) { instance_double('Bosh::Director::JobTemplateLoader') }

    describe '#render_job_instances' do
      before { job.stub(instances: [instance]) }
      let(:instance) do
        instance_double(
          'Bosh::Director::DeploymentPlan::Instance',
          :configuration_hash= => nil,
          :template_hashes= => nil,
          :rendered_templates_archive= => nil,
          :model => instance_model,
        )
      end

      let(:instance_model) do
        # not using an instance double since Sequel Model classes are a bit meta
        double(
          'Bosh::Director::Models::Instance',
          add_rendered_templates_archive: true,
          latest_rendered_templates_archive: nil,
        )
      end

      before { job_instance_renderer.stub(:render).with(instance).and_return(rendered_templates) }
      let(:rendered_templates) { [] }

      before { RenderedJobInstanceHasher.stub(new: hasher) }
      let(:hasher) do
        instance_double(
          'Bosh::Director::RenderedJobInstanceHasher',
          configuration_hash: configuration_hash,
          template_hashes: template_hashes,
        )
      end

      let(:template_hashes) do
        { 'job-template-name' => 'rendered-job-template-hash' }
      end

      before { allow(RenderedJobTemplatesPersister).to receive(:new).with(blobstore).and_return(persister) }
      let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
      let(:rendered_templates_archive) do
        instance_double(
          'Bosh::Director::DeploymentPlan::RenderedTemplatesArchive',
          blobstore_id: 'fake-new-blob-id',
          sha1: 'fake-new-sha1',
        )
      end
      let(:persister) { instance_double('Bosh::Director::RenderedJobTemplatesPersister', persist: rendered_templates_archive) }

      let(:configuration_hash) { 'fake-content-sha1' }
      let(:rendered_job_templates) { [instance_double('Bosh::Director::RenderedJobTemplate')] }

      before { allow(persister).to receive(:persist).and_return(rendered_templates_archive) }
      let(:rendered_templates_archive) do
        instance_double(
          'Bosh::Director::DeploymentPlan::RenderedTemplatesArchive',
          blobstore_id: 'fake-new-blob-id',
          sha1: 'fake-new-sha1',
        )
      end

      before { allow(DeploymentPlan::RenderedTemplatesArchive).to receive(:new).and_return(latest_rendered_templates_archive) }
      let(:latest_rendered_templates_archive) do
        instance_double(
          'Bosh::Director::DeploymentPlan::RenderedTemplatesArchive',
          blobstore_id: 'fake-latest-blob-id',
          sha1: 'fake-latest-sha1',
        )
      end

      def perform
        renderer.render_job_instances(blobstore)
      end

      context 'when instance does not have a latest archive' do
        before { allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(nil) }

        it 'persists new archive' do
          perform

          expect(persister).to have_received(:persist).with(rendered_templates)
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
          # not using an instance double since Sequel Model classes are a bit meta
          double(
            'Bosh::Directore::Models::RenderedTemplatesArchive',
            instance: instance_model,
            blobstore_id: 'fake-latest-blob-id',
            sha1: 'fake-latest-sha1',
            content_sha1: 'fake-latest-content-sha1',
            created_at: Time.new(2013, 02, 01),
          )
        end

        context 'when latest archive has matching content_sha1' do
          let(:configuration_hash) { 'fake-latest-content-sha1' }

          it 'does not persist new archive' do
            perform

            expect(persister).to_not have_received(:persist)
          end

          it 'sets rendered templates archive on the instance to archive with blobstore_id and sha1' do
            perform

            expect(DeploymentPlan::RenderedTemplatesArchive).to have_received(:new).with('fake-latest-blob-id', 'fake-latest-sha1')
            expect(instance).to have_received(:rendered_templates_archive=).with(latest_rendered_templates_archive)
          end
        end

        context 'when latest archive does have matching content_sha1' do
          let(:configuration_hash) { 'fake-latest-non-matching-content-sha1' }
          it 'persists new archive' do
            perform

            expect(persister).to have_received(:persist).with(rendered_templates)
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
        expect(job_instance_renderer).to receive(:render).with(instance)
        perform
      end

      it 'updates each instance with configuration and templates hashses' do
        perform
        expect(RenderedJobInstanceHasher).to have_received(:new).with(rendered_templates)
        expect(instance).to have_received(:configuration_hash=).with(configuration_hash)
        expect(instance).to have_received(:template_hashes=).with(template_hashes)
      end

      it 'uploads all the rendered templates for instance that has configuration_hash' do
        perform

        expect(instance).to have_received(:rendered_templates_archive=).with(rendered_templates_archive)
        expect(persister).to have_received(:persist).with(rendered_templates)
      end
    end
  end
end
