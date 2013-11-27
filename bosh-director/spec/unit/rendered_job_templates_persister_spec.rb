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
          :rendered_templates_archive= => nil,
        )
      end

      let(:instance_model) { Models::Instance.make }

      let(:rendered_job_templates) { [ instance_double('Bosh::Director::RenderedJobTemplate') ] }

      before { allow(persister).to receive(:persist_without_checking).and_return(created_archive) }
      let(:created_archive) do
        Models::RenderedTemplatesArchive.make(
          instance: instance_model,
          blobstore_id: 'fake-new-blob-id',
          sha1: 'fake-new-sha1',
          content_sha1: 'fake-new-content-sha1',
          created_at: Time.new(2013, 02, 01),
        )
      end

      def self.it_persists_new_archive
        it 'persists new archive' do
          expect(persister).to receive(:persist_without_checking).with(instance, rendered_job_templates)
          perform
        end
      end

      def self.it_does_not_persist_new_archive
        it 'does not persist new archive' do
          expect(persister).to_not receive(:persist_without_checking)
          perform
        end
      end

      def self.it_sets_rendered_templates_archive_on_instance(blobstore_id, sha1)
        it "sets rendered templates archive on the instance to archive with blobstore_id '#{blobstore_id}' and sha1 '#{sha1}'" do
          expect(instance).to receive(:rendered_templates_archive=) do |rta|
            expect(rta).to be_an_instance_of(DeploymentPlan::RenderedTemplatesArchive)
            expect(rta.blobstore_id).to eq(blobstore_id)
            expect(rta.sha1).to eq(sha1)
          end
          perform
        end
      end

      context 'when instance does not have a latest archive' do
        before { allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(nil) }
        it_persists_new_archive
        it_sets_rendered_templates_archive_on_instance 'fake-new-blob-id', 'fake-new-sha1'
      end

      context 'when instance has rendered job templates archives' do
        before { allow(instance_model).to receive(:latest_rendered_templates_archive).and_return(latest_archive) }

        let(:latest_archive) do
          Models::RenderedTemplatesArchive.make(
            instance: instance_model,
            blobstore_id: 'fake-latest-blob-id',
            sha1: 'fake-latest-sha1',
            content_sha1: 'fake-latest-content-sha1',
            created_at: Time.new(2013, 02, 01),
          )
        end

        context 'when instance\'s latest archive has matching content_sha1' do
          before { allow(instance).to receive(:configuration_hash).and_return('fake-latest-content-sha1') }
          it_does_not_persist_new_archive
          it_sets_rendered_templates_archive_on_instance 'fake-latest-blob-id', 'fake-latest-sha1'
        end

        context 'when instance\'s latest archive does have matching content_sha1' do
          before { allow(instance).to receive(:configuration_hash).and_return('fake-latest-non-matching-content-sha1') }
          it_persists_new_archive
          it_sets_rendered_templates_archive_on_instance 'fake-new-blob-id', 'fake-new-sha1'
        end
      end
    end

    describe '#persist_without_checking' do
      def perform
        persister.persist_without_checking(instance, rendered_job_templates)
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

      it 'persists blob record in the database and returns it' do
        expect {
          @created_acrhive = perform
        }.to change {
          instance_model.refresh.rendered_templates_archives.count
        }.to(1)

        @created_acrhive.refresh.tap do |rjt|
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
