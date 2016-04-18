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
        JobTemplateRenderer.new('fake-job-name', 'template-name', monit_erb, [source_erb], logger)
      end

      context 'when templates do not contain local properties' do
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

          expect(monit_erb).to have_received(:render).with(context, logger)
          expect(source_erb).to have_received(:render).with(context, logger)
        end
      end

      context 'when template has local properties' do

        let(:spec) do
          {
              'index' => 1,
              'job' => {
                  'name' => 'reg-job-name',
                  "templates"=>
                      [{"name"=>"template-name",
                        "version"=>"1bbe5ab00082797999e2101d730de64aeb601b6a",
                        "sha1"=>"728399f9ef342532c6224bce4eb5331b5c38d595",
                        "blobstore_id"=>"6c1eec85-3c08-4464-8b11-dc43acaa79f9",
                       }
                      ],
              },
              "properties"=> {
                  "template-name" => {
                      "inside"=>"insideValue",
                      "smurfs"=>{"name"=>"snoopy"},
                  }
              },
              "properties_need_filtering" => true
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
                  'job' => {
                      'name' => 'reg-job-name',
                      'templates'=>
                          [{'name'=>'template-name',
                            'version'=>'1bbe5ab00082797999e2101d730de64aeb601b6a',
                            'sha1'=>'728399f9ef342532c6224bce4eb5331b5c38d595',
                            'blobstore_id'=>'6c1eec85-3c08-4464-8b11-dc43acaa79f9',
                           }
                          ],
                  },
                  "properties"=> {
                      "inside"=> "insideValue",
                      "smurfs"=> {'name'=>'snoopy'}
                  },
                  "properties_need_filtering" => true
              }
          ).at_least(2).times
        end

      end

    end
  end
end
