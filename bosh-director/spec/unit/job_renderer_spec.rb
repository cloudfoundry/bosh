require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }
    let(:job_instance_renderer) { instance_double('Bosh::Director::JobInstanceRenderer') }
    let(:job_template_loader) { instance_double('Bosh::Director::JobTemplateLoader') }
    subject(:renderer) { described_class.new(job) }

    before do
      JobTemplateLoader.stub(new: job_template_loader)
      JobInstanceRenderer.stub(:new).with(job, job_template_loader).and_return(job_instance_renderer)
    end

    describe '#render_job_instances' do
      it 'renders all templates for all instances of a job' do
        hasher = double('hasher', configuration_hash: nil, template_hashes: nil)
        instance = instance_double(
          'Bosh::Director::DeploymentPlan::Instance',
          :configuration_hash= => nil,
          :template_hashes= => nil,
        )
        job.stub(:instances => [instance])
        RenderedJobInstanceHasher.stub(new: hasher)
        expect(job_instance_renderer).to receive(:render).with(instance)
        renderer.render_job_instances
      end

      it 'updates each instance with configuration and templates hashses' do
        instance = instance_double('Bosh::Director::DeploymentPlan::Instance')
        job.stub(instances: [instance])

        rendered_templates = double('rendered templates')
        job_instance_renderer.stub(:render).with(instance).and_return(rendered_templates)

        template_hashes = { 'job-template-name' => 'rendered-job-template-hash' }
        hasher = instance_double('Bosh::Director::RenderedJobInstanceHasher',
                                 configuration_hash: 'config-hash',
                                 template_hashes: template_hashes)

        RenderedJobInstanceHasher.stub(:new).with(rendered_templates).and_return(hasher)

        expect(instance).to receive(:configuration_hash=).with('config-hash')
        expect(instance).to receive(:template_hashes=).with(template_hashes)
        renderer.render_job_instances
      end
    end
  end
end
