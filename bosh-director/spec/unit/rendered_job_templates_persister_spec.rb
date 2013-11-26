require 'spec_helper'

module Bosh::Director
  describe RenderedJobTemplatesPersister do
    subject(:persister) { described_class.new(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

    describe '#persist' do
      def perform
        persister.persist(instance, rendered_job_templates)
      end

      let(:instance) do
        instance_double(
          'Bosh::Director::DeploymentPlan::Instance',
          model: instance_model,
          configuration_hash: 'fake-content-sha1',
        )
      end
      let(:instance_model) { Models::Instance.make }

      let(:rendered_job_templates) { [ instance_double('Bosh::Director::RenderedJobTemplate') ] }

      before { allow(CompressedRenderedJobTemplates).to receive(:new).and_return(compressed_archive) }
      let(:compressed_archive) do
        instance_double(
          'Bosh::Director::CompressedRenderedJobTemplates',
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
        expect(compressed_archive).to have_received(:write).with(rendered_job_templates)
      end

      it 'uploads the compressed archive to the blobstore after writing it' do
        compressed_archive_io = double('fake-compressed_archive_io')
        allow(compressed_archive).to receive(:contents).and_return(compressed_archive_io)
        expect(compressed_archive).to receive(:write).ordered
        expect(blobstore).to receive(:create).with(compressed_archive_io).ordered
        perform
      end

      it 'persists blob record in the database' do
        expect {
          perform
        }.to change {
          instance_model.refresh.rendered_templates_archives.count
        }.to(1)

        instance_model.rendered_templates_archives.first.tap do |rjt|
          expect(rjt.blobstore_id).to eq('fake-blobstore-id')
          expect(rjt.sha1).to eq('fake-blob-sha1')
          expect(rjt.content_sha1).to eq('fake-content-sha1')
          expect(rjt.created_at).to be <= Time.now
        end
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
