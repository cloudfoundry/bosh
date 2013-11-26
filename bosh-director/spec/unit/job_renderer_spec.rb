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

      before { RenderedJobTemplatesPersister.stub(new: persister) }
      let(:persister) { instance_double('Bosh::Director::RenderedJobTemplatesPersister', persist: true) }

      it 'renders all templates for all instances of a job' do
        expect(job_instance_renderer).to receive(:render).with(instance)
        renderer.render_job_instances
      end

      it 'updates each instance with configuration and templates hashses' do
        renderer.render_job_instances
        expect(RenderedJobInstanceHasher).to have_received(:new).with(rendered_templates)
        expect(instance).to have_received(:configuration_hash=).with('fake-config-hash')
        expect(instance).to have_received(:template_hashes=).with(template_hashes)
      end

      it 'uploads all the rendered templates for instance that has configuration_hash' do
        expect(instance).to receive(:configuration_hash=).ordered.with('fake-config-hash')
        expect(persister).to receive(:persist).ordered.with(instance, rendered_templates)
        renderer.render_job_instances
      end
    end
  end
end
