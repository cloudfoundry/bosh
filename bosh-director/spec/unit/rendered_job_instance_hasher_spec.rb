require 'spec_helper'

module Bosh::Director
  describe RenderedJobInstanceHasher do
    let(:rendered_templates) {
      [
        RenderedJobTemplate.new(
          'template-name1',
          'monit file contents 1',
          {
            'template-file1' => 'template file contents 1',
          }
        ),
        RenderedJobTemplate.new(
          'template-name2',
          'monit file contents 2',
          {
            'template-file2' => 'template file contents 2',
            'template-file3' => 'template file contents 3',
          }
        ),
      ]
    }

    subject(:hasher) { RenderedJobInstanceHasher.new(rendered_templates) }

    describe '#configuration_hash' do
      it 'returns a sha1 checksum of all rendered template files for all job templates' do
        expect(hasher.configuration_hash).to eq('0de71d6895da15482c1cda8a2d637127ea37f9b4')
      end
    end

    describe '#template_hashes' do
      it 'returns a hash of job template names to sha1 checksums of the rendered job template files' do
        expect(hasher.template_hashes).to eq(
                                            'template-name1' => '38d2e533ce5050375b8a705de2e15de196514140',
                                            'template-name2' => 'bcf1dc6d3ec54f19e10944f30550cf3b6ecd1895',
                                          )
      end
    end
  end
end
