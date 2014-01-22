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
          :model => double('InstanceModel'),
        )
      end

      before { job_instance_renderer.stub(:render).with(instance).and_return(rendered_templates) }
      let(:rendered_templates) { [] }

      before { RenderedJobInstanceHasher.stub(new: hasher) }
      let(:hasher) do
        instance_double(
          'Bosh::Director::RenderedJobInstanceHasher',
          configuration_hash: 'fake-config-hash',
          template_hashes: template_hashes,
        )
      end

      let(:template_hashes) do
        { 'job-template-name' => 'rendered-job-template-hash' }
      end

      before { allow(RenderedJobTemplatesPersister).to receive(:new).with(blobstore).and_return(persister) }
      let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
      let(:rendered_templates_archive) { instance_double('Bosh::Director::DeploymentPlan::RenderedTemplatesArchive') }
      let(:persister) { instance_double('Bosh::Director::RenderedJobTemplatesPersister', persist: rendered_templates_archive) }

      def perform
        renderer.render_job_instances(blobstore)
      end

      it 'renders all templates for all instances of a job' do
        expect(job_instance_renderer).to receive(:render).with(instance)
        perform
      end

      it 'updates each instance with configuration and templates hashses' do
        perform
        expect(RenderedJobInstanceHasher).to have_received(:new).with(rendered_templates)
        expect(instance).to have_received(:configuration_hash=).with('fake-config-hash')
        expect(instance).to have_received(:template_hashes=).with(template_hashes)
      end

      it 'uploads all the rendered templates for instance that has configuration_hash' do
        perform

        expect(instance).to have_received(:rendered_templates_archive=).with(rendered_templates_archive)
        expect(persister).to have_received(:persist).with('fake-config-hash', instance.model, rendered_templates)
      end
    end
  end
end
