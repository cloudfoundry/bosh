require 'spec_helper'
require 'bosh/director/core/templates/rendered_job_instance'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'

module Bosh::Director::Core::Templates
  describe RenderedJobInstance do
    subject(:instance) { described_class.new(templates) }

    describe '#configuration_hash' do
      let(:templates) {
        [
          RenderedJobTemplate.new(
            'template-name1',
            'monit file contents 1',
            [
              instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                              src_name: 'template-file1',
                              contents: 'template file contents 1')
            ]
          ),
          RenderedJobTemplate.new(
            'template-name2',
            'monit file contents 2',
            [
              instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                              src_name: 'template-file3',
                              contents: 'template file contents 3'),
              instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                              src_name: 'template-file2',
                              contents: 'template file contents 2'),
            ]
          ),
        ]
      }

      it 'returns a sha1 checksum of all rendered template files for all job templates' do
        expect(instance.configuration_hash).to eq('0de71d6895da15482c1cda8a2d637127ea37f9b4')
      end
    end

    describe '#template_hashes' do
      let(:templates) {
        [
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name1',
            template_hash: 'hash1',
          ),
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name2',
            template_hash: 'hash2',
          ),
        ]
      }

      it 'returns a hash of job template names to sha1 checksums of the rendered job template files' do
        expect(instance.template_hashes).to eq('template-name1' => 'hash1', 'template-name2' => 'hash2')
      end
    end

    describe '#persist' do
      let(:templates) {
        [
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name1',
            template_hash: 'hash1',
          ),
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name2',
            template_hash: 'hash2',
          ),
        ]
      }

      def perform
        instance.persist(blobstore)
      end

      let(:blobstore) { double('Bosh::Blobstore::BaseClient') }

      let(:templates) { [instance_double('Bosh::Director::Core::Templates::RenderedJobTemplate')] }

      before { allow(CompressedRenderedJobTemplates).to receive(:new).and_return(compressed_archive) }
      let(:compressed_archive) do
        instance_double(
          'Bosh::Director::Core::Templates::CompressedRenderedJobTemplates',
          write: nil,
          contents: nil,
          sha1: 'fake-blob-sha1',
        )
      end

      before { allow(blobstore).to receive(:create).and_return('fake-blobstore-id') }

      before { Tempfile.stub(:new).and_return(temp_file) }
      let(:temp_file) { instance_double('Tempfile', path: '/temp/archive/path.tgz', close!: nil) }

      it 'compresses the provided RenderedJobTemplate objects' do
        perform
        expect(CompressedRenderedJobTemplates).to have_received(:new).with('/temp/archive/path.tgz')
        expect(compressed_archive).to have_received(:write).with(templates)
      end

      it 'uploads the compressed archive to the blobstore after writing it' do
        compressed_archive_io = double('fake-compressed_archive_io')
        allow(compressed_archive).to receive(:contents).and_return(compressed_archive_io)
        expect(compressed_archive).to receive(:write).ordered
        expect(blobstore).to receive(:create).with(compressed_archive_io).ordered
        perform
      end

      it 'returns a rendered template archive' do
        rta = perform
        expect(rta.blobstore_id).to eq('fake-blobstore-id')
        expect(rta.sha1).to eq('fake-blob-sha1')
      end

      it 'closes temporary file after the upload' do
        expect(blobstore).to receive(:create).ordered
        expect(temp_file).to receive(:close!).ordered
        perform
      end

      it 'closes temporary file even when compression fails' do
        error = Exception.new('error')
        allow(compressed_archive).to receive(:write).and_raise(error)
        expect(temp_file).to receive(:close!).ordered
        expect { perform }.to raise_error(error)
      end

      it 'closes temporary file even when upload fails' do
        error = Exception.new('error')
        expect(blobstore).to receive(:create).and_raise(error)
        expect(temp_file).to receive(:close!).ordered
        expect { perform }.to raise_error(error)
      end
    end
  end
end
