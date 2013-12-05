require 'spec_helper'

module Bosh::Director
  describe RenderedJobInstanceHasher do

    describe '#configuration_hash' do
      let(:rendered_templates) {
        [
          RenderedJobTemplate.new(
            'template-name1',
            'monit file contents 1',
            [
              instance_double('Bosh::Director::RenderedFileTemplate',
                              src_name: 'template-file1',
                              contents: 'template file contents 1')
            ]
          ),
          RenderedJobTemplate.new(
            'template-name2',
            'monit file contents 2',
            [
              instance_double('Bosh::Director::RenderedFileTemplate',
                              src_name: 'template-file3',
                              contents: 'template file contents 3'),
              instance_double('Bosh::Director::RenderedFileTemplate',
                              src_name: 'template-file2',
                              contents: 'template file contents 2'),
            ]
          ),
        ]
      }
      subject(:hasher) { RenderedJobInstanceHasher.new(rendered_templates) }

      it 'returns a sha1 checksum of all rendered template files for all job templates' do
        expect(hasher.configuration_hash).to eq('0de71d6895da15482c1cda8a2d637127ea37f9b4')
      end
    end

    describe '#template_hashes' do
      let(:rendered_templates) {
        [
          instance_double('Bosh::Director::RenderedJobTemplate', name: 'template-name1', template_hash: 'hash1'),
          instance_double('Bosh::Director::RenderedJobTemplate', name: 'template-name2', template_hash: 'hash2'),
        ]
      }
      subject(:hasher) { RenderedJobInstanceHasher.new(rendered_templates) }
      it 'returns a hash of job template names to sha1 checksums of the rendered job template files' do
        expect(hasher.template_hashes).to eq('template-name1' => 'hash1', 'template-name2' => 'hash2')
      end
    end
  end
end
