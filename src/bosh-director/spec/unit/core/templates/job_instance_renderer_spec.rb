require 'spec_helper'
require 'bosh/director/core/templates/job_instance_renderer'
require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'

module Bosh::Director::Core::Templates
  describe JobInstanceRenderer do
    subject(:job_instance_renderer) { JobInstanceRenderer.new(jobs, job_template_loader) }
    let(:job_template_loader) { instance_double('Bosh::Director::Core::Templates::JobTemplateLoader') }
    let(:job_template_renderer) { instance_double('Bosh::Director::Core::Templates::JobTemplateRenderer') }
    let(:instance_group_name) { 'fake-instance-group-name' }
    let(:properties) { {} }
    let(:spec) do
      {
        'name' => instance_group_name,
        'job' => { # <- here 'job' is the Bosh v1 term for 'instance group'
          'name' => instance_group_name
        },
        'properties' => properties
      }
    end

    describe '#render' do
      let(:expected_rendered_job_instance) { instance_double('Bosh::Director::Core::Templates::RenderedJobInstance') }

      before { allow(RenderedJobInstance).to receive(:new).and_return(expected_rendered_job_instance) }

      context 'when job has no templates' do
        let(:jobs) { [] }

        it 'returns empty array' do

          rendered_instance = job_instance_renderer.render(spec)
          expect(RenderedJobInstance).to have_received(:new).with([])
          expect(rendered_instance).to eq(expected_rendered_job_instance)
        end
      end

      context 'when job has one job_template' do
        let(:jobs) { [double('template', name: 'a')] }
        let(:expected_rendered_templates) { [double('rendered template')] }

        before do
          allow(job_template_renderer).to receive(:render).with(spec).and_return(expected_rendered_templates[0])
        end

        it 'returns the rendered template for the given instance' do
          allow(job_template_loader).to receive(:process).with(jobs[0]).and_return(job_template_renderer)

          job_instance_renderer.render(spec)
          expect(RenderedJobInstance).to have_received(:new).with(expected_rendered_templates)
        end

        context 'when called for multiple instances' do
          it 'only processes the source job templates once' do
            expect(job_template_loader).to receive(:process).with(jobs[0]).and_return(job_template_renderer)

            job_instance_renderer.render(spec)
            job_instance_renderer.render(spec)
          end
        end
      end

      context 'when job has multiple job_templates' do
        let(:jobs) { [double('template1', name: 'b'), double('template2', name: 'a')] }
        let(:expected_rendered_templates) do
          [
            double('rendered job template1'),
            double('rendered job template2'),
          ]
        end
        let(:job_template_renderer2) { instance_double('Bosh::Director::Core::Templates::JobTemplateRenderer') }

        before do
          allow(job_template_loader).to receive(:process).with(jobs[0]).and_return(job_template_renderer)
          allow(job_template_loader).to receive(:process).with(jobs[1]).and_return(job_template_renderer2)

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

    describe 'validate_properties!' do
      let(:job_name) { 'fake-job-name' }
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', name: job_name) }
      let(:jobs) { [job] }
      let(:properties) do
        {
          job_name => {
            'a_property' => 'a_value'
          }
        }
      end

      before do
        allow(job_template_loader).to receive(:process).with(job).and_return(job_template_renderer)
        allow(job_template_renderer).to receive(:properties_schema).and_return(properties_schema)
      end

      context 'when the job has a json schema' do
        let(:properties_schema) { { "schema": true} }

        it 'calls the schema verifier' do
          expect(JobSchemaValidator).to receive(:validate).with(job_name: job_name, schema: properties_schema, properties: properties[job_name])
          job_instance_renderer.validate_properties!(spec)
        end
      end

      context 'when the job does not have a json schema' do
        let(:properties_schema) { nil }

        it 'does not error' do
          expect { job_instance_renderer.validate_properties!(spec) }.not_to raise_error
        end
      end
    end
  end
end
