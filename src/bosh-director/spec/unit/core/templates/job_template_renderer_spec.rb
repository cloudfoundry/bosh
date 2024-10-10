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
          src_filepath: 'fake-template-src-name',
          dest_filepath: 'fake-template-dest-name',
          render: 'test template',
        )
      end

      let(:spec) do
        {
          'index' => 1,
          'job' => {
            'name' => 'fake-instance-group-name',
          },
        }
      end

      let(:links_provided) { [] }
      let(:release) { double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-release-name', version: '0.1') }
      let(:job_template_model) { double('Bosh::Director::Models::Template', provides: links_provided) }
      let(:instance_job) do
        double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job-name', release: release, model: job_template_model)
      end
      let(:logger) { instance_double('Logger', debug: nil) }
      let(:dns_encoder) { double('some DNS encoder') }
      let(:link_provider_intents) { [] }

      subject(:job_template_renderer) do
        JobTemplateRenderer.new(
          instance_job: instance_job,
          monit_erb: monit_erb,
          source_erbs: [source_erb],
          logger: logger,
          link_provider_intents: link_provider_intents,
          dns_encoder: dns_encoder,
        )
      end

      context 'when templates do not contain local properties' do
        let(:context) { instance_double('Bosh::Template::EvaluationContext') }
        let(:context_copy) { instance_double('Bosh::Template::EvaluationContext') }
        before do
          allow(Bosh::Template::EvaluationContext).to receive(:new).and_return(context)
          allow(Bosh::Common::DeepCopy).to receive(:copy).and_call_original
          allow(Bosh::Common::DeepCopy).to receive(:copy).with(context).and_return(context_copy)
          allow(Bosh::Common::DeepCopy).to receive(:copy).with(context_copy).and_return(context_copy)
        end

        it 'returns a collection of rendered templates' do
          rendered_templates = job_template_renderer.render(spec)

          expect(rendered_templates.monit).to eq('monit file')
          rendered_file_template = rendered_templates.templates.first
          expect(rendered_file_template.src_filepath).to eq('fake-template-src-name')
          expect(rendered_file_template.dest_filepath).to eq('fake-template-dest-name')
          expect(rendered_file_template.contents).to eq('test template')

          expect(monit_erb).to have_received(:render).with(context_copy, logger)
          expect(source_erb).to have_received(:render).with(context_copy, logger)
        end
      end

      context 'when template has local properties' do
        let(:spec) do
          {
            'index' => 1,
            'name' => 'instance-group-name',
            'job' => { # <- here 'job' is the Bosh v1 term for 'instance group'
              'name' => 'reg-instance-group-name',
              'templates' => # <- here 'template' is the Bosh v1 term for 'job'
                      [{ 'name' => 'fake-job-name',
                         'version' => '1bbe5ab00082797999e2101d730de64aeb601b6a',
                         'sha1' => '728399f9ef342532c6224bce4eb5331b5c38d595',
                         'blobstore_id' => '6c1eec85-3c08-4464-8b11-dc43acaa79f9' }],
            },
            'properties' => {
              'fake-job-name' => {
                'inside' => 'insideValue',
                'smurfs' => { 'name' => 'snoopy' },
              },
            },
            'properties_need_filtering' => true,
            'release' => { 'name' => 'fake-release-name', 'version' => '0.1' },
          }
        end

        before do
          allow(Bosh::Template::EvaluationContext).to receive(:new)
        end

        it 'should adjust the spec passed to the evaluation context' do
          job_template_renderer.render(spec)
          expect(Bosh::Template::EvaluationContext).to have_received(:new).with(
            {
              'index' => 1,
              'name' => 'instance-group-name',
              'job' => { # <- here 'job' is the Bosh v1 term for 'instance group'
                'name' => 'reg-instance-group-name',
                'templates' => # <- here 'template' is the Bosh v1 term for 'job'
                        [{ 'name' => 'fake-job-name',
                           'version' => '1bbe5ab00082797999e2101d730de64aeb601b6a',
                           'sha1' => '728399f9ef342532c6224bce4eb5331b5c38d595',
                           'blobstore_id' => '6c1eec85-3c08-4464-8b11-dc43acaa79f9' }],
              },
              'properties' => { # note: loses 'fake-job-name' from :spec
                'inside' => 'insideValue',
                'smurfs' => { 'name' => 'snoopy' },
              },
              'properties_need_filtering' => true,
              'release' => { 'name' => 'fake-release-name', 'version' => '0.1' },
            }, dns_encoder
          ).once
        end

        context 'rendering templates returns errors' do
          let(:job_template_renderer) do
            JobTemplateRenderer.new(
              instance_job: instance_job,
              monit_erb: monit_erb,
              source_erbs: [source_erb, source_erb],
              logger: logger,
              link_provider_intents: link_provider_intents,
              dns_encoder: dns_encoder,
            )
          end

          before do
            allow(source_erb).to receive(:render).and_raise('Error filling something in the template')
          end

          it 'formats the error messages is a generic way' do
            expected_error_msg = <<~EXPECTED.strip
              - Unable to render templates for job 'fake-job-name'. Errors are:
                - Error filling something in the template
                - Error filling something in the template
            EXPECTED

            expect do
              job_template_renderer.render(spec)
            end.to(raise_error { |error| expect(error.message).to eq(expected_error_msg) })
          end
        end
      end

      context 'when spec has links' do
        let(:raw_spec) do
          {
            'name' => 'fake-instance-group-name',
            'index' => 1,
            'job' => { # <- here 'job' is the Bosh v1 term for 'instance group'
              'name' => 'fake-instance-group-name',
            },
            'properties_need_filtering' => true,
            'links' => {
              'fake-job-name' => {
                'db_link' => {
                  'properties' => { 'foo' => 'bar' },
                  'instances' => [{ 'name' => 'mysql1' }, { 'name' => 'mysql' }]
                },
                'backup_db' => {
                  'properties' => { 'moop' => 'yar' },
                  'instances' => [{ 'name' => 'postgres1' }, { 'name' => 'postgres' }]
                },
              },
            },
            'release' => { 'name' => 'fake-release-name', 'version' => '0.1' },
          }
        end

        let(:modified_spec) do
          {
            'name' => 'fake-instance-group-name',
            'index' => 1,
            'job' => { # <- here 'job' is the Bosh v1 term for 'instance group'
              'name' => 'fake-instance-group-name',
            },
            'properties_need_filtering' => true,
            'links' => {
              'db_link' => {
                'properties' => { 'foo' => 'bar' },
                'instances' => [{ 'name' => 'mysql1' }, { 'name' => 'mysql' }],
              },
              'backup_db' => {
                'properties' => { 'moop' => 'yar' },
                'instances' => [{ 'name' => 'postgres1' }, { 'name' => 'postgres' }],
              },
            },
            'release' => { 'name' => 'fake-release-name', 'version' => '0.1' },
          }
        end

        let(:provider1) do
          double('provider1', instance_group: 'fake-instance-group-name', name: 'fake-job-name')
        end

        let(:provider2) do
          double('provider2', instance_group: 'another-instance-group-name')
        end

        let(:provider3) do
          double('provider3', instance_group: 'fake-instance-group-name', name: 'another-job-name')
        end

        let(:provider_intent) do
          double(
            'provider_intent',
            canonical_name: 'my-link',
            original_name: 'db_link',
            type: 'conn',
            group_name: 'my-link-conn',
            link_provider: provider1,
          )
        end

        let(:another_provider_intent) do
          double(
            'provider_intent',
            canonical_name: 'another-link',
            original_name: 'backup_db',
            type: 'other',
            group_name: 'another-link-other',
            link_provider: provider2,
          )
        end

        let(:yet_another_provider_intent) do
          double(
            'provider_intent',
            canonical_name: 'yet-another-link',
            original_name: 'dontcare',
            type: 'type3',
            group_name: 'yet-another-link-type3',
            link_provider: provider3,
          )
        end

        let(:link_provider_intents) { [provider_intent, another_provider_intent, yet_another_provider_intent] }

        before do
          allow(Bosh::Template::EvaluationContext).to receive(:new)
          allow(dns_encoder).to receive(:id_for_group_tuple).and_return('10', '1', '-1')
        end

        it 'should have EvaluationContext called with correct spec' do
          job_template_renderer.render(raw_spec)
          expect(Bosh::Template::EvaluationContext).to have_received(:new).with(modified_spec, dns_encoder).once
        end

        it 'appends a rendered template with deterministic link dns data' do
          rendered_files = job_template_renderer.render(raw_spec).templates

          expect(dns_encoder).to have_received(:id_for_group_tuple).once

          rendered_links_file = rendered_files.pop
          expect(rendered_links_file.src_filepath).to(eq('.bosh/links.json'))
          expect(rendered_links_file.dest_filepath).to(eq('.bosh/links.json'))

          expect(JSON.parse(rendered_links_file.contents)).to eq(
            [
              {
                'name' => provider_intent.canonical_name,
                'type' => provider_intent.type,
                'group' => '10',
              },
            ],
          )
        end
      end
    end
  end
end
