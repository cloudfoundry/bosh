require 'spec_helper'

module Bosh::Director
  describe RenderedTemplatesUploader do
    let(:rendered_job_templates) do
      [
        instance_double('Bosh::Director::RenderedJobTemplate'),
        instance_double('Bosh::Director::RenderedJobTemplate'),
      ]
    end

    let(:compressed_archive) do
      instance_double('Bosh::Director::CompressedRenderedJobTemplates', write: nil, contents: 'contents of compressed-archive.tgz')
    end

    let(:blobstore) do
      instance_double('Bosh::Blobstore::BaseClient', create: nil)
    end

    subject(:uploader) do
      RenderedTemplatesUploader.new(blobstore)
    end

    before do
      allow(CompressedRenderedJobTemplates).to receive(:new).and_return(compressed_archive)
    end

    context 'instantiating with defaults' do
      it 'should use a null blobstore until we have implemented proper cleanup' do
        null_blobstore = instance_double('Bosh::Blobstore::NullBlobstoreClient', create: nil)

        Bosh::Blobstore::NullBlobstoreClient.stub(:new).and_return(null_blobstore)

        uploader = RenderedTemplatesUploader.new

        expect(uploader.instance_variable_get(:@blobstore)).to eq(null_blobstore)
      end
    end

    describe '#upload' do
      before { Tempfile.stub(:new).and_return(temp_file) }
      let(:temp_file) { instance_double('Tempfile', path: '/temp/archive/path.tgz', close!: nil) }

      def perform
        uploader.upload(rendered_job_templates)
      end

      it 'compresses the provided RenderedJobTemplate objects' do
        perform
        expect(CompressedRenderedJobTemplates).to have_received(:new).with('/temp/archive/path.tgz')
        expect(compressed_archive).to have_received(:write).with(rendered_job_templates)
      end

      it 'uploads the compressed archive to the blobstore after writing it' do
        expect(compressed_archive).to receive(:write).ordered
        expect(blobstore).to receive(:create).with('contents of compressed-archive.tgz').ordered
        perform
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
