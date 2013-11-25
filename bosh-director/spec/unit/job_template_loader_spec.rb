# encoding: UTF-8
# encoding is needed for correctly comparing expected ERB below
require 'spec_helper'

module Bosh::Director
  describe JobTemplateLoader do
    describe '#process' do
      subject(:job_template_loader) { JobTemplateLoader.new }

      it 'returns the jobs template erb objects' do
        template_contents = create_job('foo', 'monit file',
                                       { 'test' => {
                                         'destination' => 'test_dst',
                                         'contents' => 'test contents' }
                                       })

        tmp_file = Tempfile.new('blob')
        File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
        job_template = instance_double('Bosh::Director::DeploymentPlan::Template', download_blob: tmp_file.path, name: 'foo')

        container = job_template_loader.process(job_template)

        expect(container.monit_template.filename).to eq('foo/monit')
        expect(container.monit_template.src).to eq ERB.new('monit file').src

        src_template = container.templates.first
        expect(src_template.src_name).to eq('test')
        expect(src_template.dest_name).to eq('test_dst')
        expect(src_template.erb_file.filename).to eq('foo/test')
        expect(src_template.erb_file.src).to eq ERB.new('test contents').src
      end

      it 'returns only monit erb object when no other templates exist' do
        template_contents = create_job('foo', 'monit file', {})

        tmp_file = Tempfile.new('blob')
        File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
        job_template = instance_double('Bosh::Director::DeploymentPlan::Template', download_blob: tmp_file.path, name: 'foo')


        container = job_template_loader.process(job_template)

        expect(container.monit_template.filename).to eq('foo/monit')
        expect(container.monit_template.src).to eq ERB.new('monit file').src

        expect(container.templates).to eq([])
      end
    end
  end
end
