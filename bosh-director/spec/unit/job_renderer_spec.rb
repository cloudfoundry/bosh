require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }
    let(:job_instance_renderer) { instance_double('Bosh::Director::JobInstanceRenderer') }
    let(:job_template_loader) { instance_double('Bosh::Director::JobTemplateLoader') }


    subject(:renderer) { JobRenderer.new(job) }

    before do
      JobTemplateLoader.stub(new: job_template_loader)
      JobInstanceRenderer.stub(:new).with(job, job_template_loader).and_return(job_instance_renderer)
    end

    describe '#render_job_instances' do
      let(:rendered_templates) { [] }

      let(:template_hashes) do
        { 'job-template-name' => 'rendered-job-template-hash' }
      end

      let(:hasher) do
        instance_double('Bosh::Director::RenderedJobInstanceHasher',
                        configuration_hash: 'config-hash',
                        template_hashes: template_hashes)
      end

      let(:instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance',
                        :configuration_hash= => nil,
                        :template_hashes= => nil)
      end

      let(:uploader) do
        instance_double('Bosh::Director::RenderedTemplatesUploader', upload: true)
      end

      before do
        job.stub(instances: [instance])
        job_instance_renderer.stub(:render).with(instance).and_return(rendered_templates)
        RenderedJobInstanceHasher.stub(new: hasher)
        RenderedTemplatesUploader.stub(new: uploader)
      end

      it 'renders all templates for all instances of a job' do
        expect(job_instance_renderer).to receive(:render).with(instance)
        renderer.render_job_instances
      end

      it 'updates each instance with configuration and templates hashses' do
        renderer.render_job_instances

        expect(RenderedJobInstanceHasher).to have_received(:new).with(rendered_templates)
        expect(instance).to have_received(:configuration_hash=).with('config-hash')
        expect(instance).to have_received(:template_hashes=).with(template_hashes)
      end

      it 'uploads all the rendered templates' do
        renderer.render_job_instances

        expect(uploader).to have_received(:upload).with(rendered_templates)
      end
    end
  end
end
