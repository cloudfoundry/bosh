require 'spec_helper'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe RenderedTemplatesWriter do
    include FakeFS::SpecHelpers

    let(:rendered_file_template) do
      instance_double('Bosh::Director::RenderedFileTemplate',
                      dest_name: 'bin/script-filename',
                      contents: 'script file contents'
      )
    end

    let(:rendered_file_template_with_deep_path) do
      instance_double('Bosh::Director::RenderedFileTemplate',
                      dest_name: 'config/with/deeper/path/filename.cfg',
                      contents: 'config file contents'
      )
    end

    let(:rendered_template) do
      instance_double('Bosh::Director::RenderedJobTemplate',
                      name: 'job-template-name',
                      monit: 'monit file contents',
                      templates: [rendered_file_template, rendered_file_template_with_deep_path]
      )
    end

    subject(:rendered_templates_writer) { RenderedTemplatesWriter.new }

    before do
      FileUtils.mkdir_p('/output-path')
    end

    describe '#write' do
      it 'writes the rendered templates to the provided directory' do
        rendered_templates_writer.write([rendered_template], '/output-path')

        expect(File.read('/output-path/job-template-name/monit')).to eq('monit file contents')
        expect(File.read('/output-path/job-template-name/bin/script-filename')).to eq('script file contents')
        expect(File.read('/output-path/job-template-name/config/with/deeper/path/filename.cfg')).to eq('config file contents')
      end
    end
  end
end
