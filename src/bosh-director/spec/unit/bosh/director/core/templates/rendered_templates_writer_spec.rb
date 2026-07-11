require 'spec_helper'
require 'bosh/director/core/templates/rendered_templates_writer'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'

module Bosh::Director::Core::Templates
  describe RenderedTemplatesWriter do
    let(:rendered_file_template) do
      instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                      dest_filepath: 'bin/script-filename',
                      contents: 'script file contents'
      )
    end

    let(:rendered_file_template_with_deep_path) do
      instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                      dest_filepath: 'config/with/deeper/path/filename.cfg',
                      contents: 'config file contents'
      )
    end

    let(:rendered_template) do
      instance_double('Bosh::Director::Core::Templates::RenderedJobTemplate',
                      name: 'job-template-name',
                      monit: 'monit file contents',
                      templates: [rendered_file_template, rendered_file_template_with_deep_path]
      )
    end

    subject(:rendered_templates_writer) { RenderedTemplatesWriter.new }

    let(:tmpdir) { Dir.mktmpdir }
    after { FileUtils.rm_rf(tmpdir) }

    describe '#write' do
      it 'writes the rendered templates to the provided directory' do
        rendered_templates_writer.write([rendered_template], tmpdir)

        expect(File.read(File.join(tmpdir, 'job-template-name', 'monit'))).to eq('monit file contents')
        expect(File.read(File.join(tmpdir, 'job-template-name', 'bin', 'script-filename'))).to eq('script file contents')
        expect(File.read(File.join(tmpdir, 'job-template-name', 'config', 'with', 'deeper', 'path', 'filename.cfg'))).to eq('config file contents')
      end
    end
  end
end
