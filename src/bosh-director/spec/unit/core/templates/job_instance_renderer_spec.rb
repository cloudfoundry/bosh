require 'spec_helper'
require 'bosh/director/core/templates/job_instance_renderer'
require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'

module Bosh::Director::Core::Templates
  describe JobInstanceRenderer do
    describe '#render' do
      subject(:job_instance_renderer) { JobInstanceRenderer.new(templates, job_template_loader) }

      let(:spec) do
        {
          'name' => 'fake-instance-group-name',
          'job' => { # <- here 'job' is the Bosh v1 term for 'instance group'
            'name' => 'fake-instance-group-name'
          }
        }
      end
      let(:job_template_loader) { instance_double('Bosh::Director::Core::Templates::JobTemplateLoader') }
      let(:job_template_renderer) { instance_double('Bosh::Director::Core::Templates::JobTemplateRenderer') }

      before { allow(RenderedJobInstance).to receive(:new).and_return(expected_rendered_job_instance) }
      let(:expected_rendered_job_instance) { instance_double('Bosh::Director::Core::Templates::RenderedJobInstance') }

      context 'when job has no templates' do
        let(:templates) { [] }

        it 'returns empty array' do

          rendered_instance = job_instance_renderer.render(spec)
          expect(RenderedJobInstance).to have_received(:new).with([])
          expect(rendered_instance).to eq(expected_rendered_job_instance)
        end
      end

      context 'when job has one job_template' do
        let(:templates) { [double('template', name: 'a')] }
        let(:expected_rendered_templates) { [double('rendered template')] }

        before do
          allow(job_template_renderer).to receive(:render).with(spec).and_return(expected_rendered_templates[0])
        end

        it 'returns the rendered template for the given instance' do
          allow(job_template_loader).to receive(:process).with(templates[0]).and_return(job_template_renderer)

          job_instance_renderer.render(spec)
          expect(RenderedJobInstance).to have_received(:new).with(expected_rendered_templates)
        end

        context 'when called for multiple instances' do
          it 'only processes the source job templates once' do
            expect(job_template_loader).to receive(:process).with(templates[0]).and_return(job_template_renderer)

            job_instance_renderer.render(spec)
            job_instance_renderer.render(spec)
          end
        end
      end

      context 'when job has multiple job_templates' do
        let(:templates) { [double('template1', name: 'b'), double('template2', name: 'a')] }
        let(:expected_rendered_templates) do
          [
            double('rendered job template1'),
            double('rendered job template2'),
          ]
        end
        let(:job_template_renderer2) { instance_double('Bosh::Director::Core::Templates::JobTemplateRenderer') }

        before do
          allow(job_template_loader).to receive(:process).with(templates[0]).and_return(job_template_renderer)
          allow(job_template_loader).to receive(:process).with(templates[1]).and_return(job_template_renderer2)

          allow(job_template_renderer).to receive(:render).with(spec).and_return(expected_rendered_templates[0])
          allow(job_template_renderer2).to receive(:render).with(spec).and_return(expected_rendered_templates[1])
        end

        it 'returns the rendered templates for an instance' do
          job_instance_renderer.render(spec)
          expect(RenderedJobInstance).to have_received(:new).with(expected_rendered_templates)
        end

        context 'when job renderer returns an error' do
          let(:err_msg_1) do
            <<-MESSAGE.strip
- Unable to render templates for job 'fake-job-name-1'. Errors are:
  - Error filling something in the template
  - Error filling something in the template
            MESSAGE
          end

          let(:err_msg_2) do
            <<-MESSAGE.strip
- Unable to render templates for job 'fake-job-name-2'. Errors are:
  - Error filling something in the template
  - Error filling something in the template
            MESSAGE
          end

          before do
            allow(job_template_renderer).to receive(:render).and_raise(err_msg_1)
            allow(job_template_renderer2).to receive(:render).and_raise(err_msg_2)
          end

          it 'formats the error messages is a generic way' do
            expected_error_msg = <<-EXPECTED.strip
- Unable to render jobs for instance group 'fake-instance-group-name'. Errors are:
  - Unable to render templates for job 'fake-job-name-1'. Errors are:
    - Error filling something in the template
    - Error filling something in the template
  - Unable to render templates for job 'fake-job-name-2'. Errors are:
    - Error filling something in the template
    - Error filling something in the template
            EXPECTED

            expect {
              job_instance_renderer.render(spec)
            }.to raise_error { |error|
              expect(error.message).to eq(expected_error_msg)
            }
          end
        end
      end
    end
  end
end
