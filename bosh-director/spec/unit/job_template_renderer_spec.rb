require 'spec_helper'

module Bosh::Director
  describe JobTemplateRenderer do
    describe '#render' do
      let(:monit_template) { ERB.new('monit file') }
      let(:fake_template) { ERB.new('test template') }
      let(:fake_templates) { { 'fake-template' => fake_template } }
      let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', spec: {}, index: 1) }

      subject(:job_template_renderer) { JobTemplateRenderer.new('template-name', monit_template, fake_templates) }

      before do
        monit_template.filename = 'monit-filename'
        fake_template.filename = 'template-filename'
      end

      it 'returns a collection of rendered templates' do
        rendered_templates = job_template_renderer.render('foo', instance)

        expect(rendered_templates.monit).to eq('monit file')
        expect(rendered_templates.templates['fake-template']).to eq('test template')
      end

      context 'when there is an error during erb rendering' do
        let(:fake_template) { ERB.new('<% nil.no_method %>') }

        it 'wraps the error and raises a new one' do
          expect {
            job_template_renderer.render('failing-job', instance)
          }.to raise_error("Error filling in template `template-filename' for `failing-job/1' (line 1: undefined method `no_method' for nil:NilClass)")
        end
      end
    end
  end
end
