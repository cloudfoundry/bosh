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
      instance_double('Bosh::Director::CompressedRenderedJobTemplates', contents: 'contents of compressed-archive.tgz')
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
      it 'compresses the provided RenderedJobTemplate objects' do
        uploader.upload(rendered_job_templates)

        expect(CompressedRenderedJobTemplates).to have_received(:new).with(rendered_job_templates)
      end


      it 'uploads the compressed archive to the blobstore' do
        uploader.upload(rendered_job_templates)

        expect(blobstore).to have_received(:create).with('contents of compressed-archive.tgz')
      end
    end
  end
end
