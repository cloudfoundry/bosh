require 'spec_helper'
require 'logger'
require 'bosh/director/core/templates/job_template_renderer'
require 'bosh/director/core/templates/source_erb'

module Bosh::Director::Core::Templates
  describe JobTemplateRenderer do
    describe '#render' do
      let(:monit_erb) do
        instance_double(
          'Bosh::Director::Core::Templates::SourceErb',
          render: 'monit file',
        )
      end

      let(:source_erb) do
        instance_double(
          'Bosh::Director::Core::Templates::SourceErb',
          src_name: 'fake-template-src-name',
          dest_name: 'fake-template-dest-name',
          render: 'test template',
        )
      end

      let(:spec) do
        {
          'index' => 1,
          'job' => {
            'name' => 'fake-job-name'
          }
        }
      end
      let(:logger) { instance_double('Logger', debug: nil) }

      subject(:job_template_renderer) do
        JobTemplateRenderer.new('template-name', monit_erb, [source_erb], logger)
      end

      let(:context) { instance_double('Bosh::Template::EvaluationContext') }
      before do
        allow(Bosh::Template::EvaluationContext).to receive(:new).and_return(context)
      end

      it 'returns a collection of rendered templates' do
        rendered_templates = job_template_renderer.render(spec)

        expect(rendered_templates.monit).to eq('monit file')
        rendered_file_template = rendered_templates.templates.first
        expect(rendered_file_template.src_name).to eq('fake-template-src-name')
        expect(rendered_file_template.dest_name).to eq('fake-template-dest-name')
        expect(rendered_file_template.contents).to eq('test template')

        expect(monit_erb).to have_received(:render).with(context, 'fake-job-name', 1, logger)
        expect(source_erb).to have_received(:render).with(context, 'fake-job-name', 1, logger)
      end

    end
  end
end
