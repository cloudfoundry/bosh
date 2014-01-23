require 'spec_helper'
require 'logger'
require 'bosh/director/core/templates/job_template_renderer'
require 'bosh/director/core/templates/src_file_template'

module Bosh::Director::Core::Templates
  describe JobTemplateRenderer do
    describe '#render' do
      let(:monit_template) { ERB.new('monit file') }
      let(:fake_template) { ERB.new('test template') }
      let(:fake_templates) do
        [
          instance_double('Bosh::Director::Core::Templates::SrcFileTemplate',
                          src_name: 'fake-template-src-name',
                          dest_name: 'fake-template-dest-name',
                          erb_file: fake_template)
        ]
      end
      let(:instance) { double('Bosh::Director::DeploymentPlan::Instance', spec: {}, index: 1) }
      let(:logger) { instance_double('Logger', debug: nil) }

      subject(:job_template_renderer) do
        JobTemplateRenderer.new('template-name', monit_template, fake_templates, logger)
      end

      before do
        monit_template.filename = 'monit-filename'
        fake_template.filename = 'template-filename'
      end

      it 'returns a collection of rendered templates' do
        rendered_templates = job_template_renderer.render('foo', instance)

        expect(rendered_templates.monit).to eq('monit file')
        rendered_file_template = rendered_templates.templates.first
        expect(rendered_file_template.src_name).to eq('fake-template-src-name')
        expect(rendered_file_template.dest_name).to eq('fake-template-dest-name')
        expect(rendered_file_template.contents).to eq('test template')
      end

      context 'when there is an error during erb rendering' do
        let(:fake_template) { ERB.new('<% nil.no_method %>') }

        it 'wraps the error and raises a new one' do
          expected_message = "Error filling in template `template-filename' for `failing-job/1' " +
                             "(line 1: undefined method `no_method' for nil:NilClass)"
          expect {
            job_template_renderer.render('failing-job', instance)
          }.to raise_error(expected_message)
        end
      end
    end
  end
end
