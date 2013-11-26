require 'spec_helper'
require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  describe RenderedJobTemplatesCleaner do
    subject(:rendered_job_templates) { described_class.new(instance_model, blobstore) }
    let(:instance_model) { Models::Instance.make }
    let(:blobstore) { Bosh::Blobstore::NullBlobstoreClient.new }

    describe '#clean' do
      before { allow(blobstore).to receive(:delete) }

      def perform
        rendered_job_templates.clean
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'does nothing' do
          expect { perform }.to_not raise_error
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        before do
          Models::RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: instance_model,
            created_at: Time.new(2013, 02, 01),
          )

          Models::RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: instance_model,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'removes stale templates for the current instance from the blobstore' do
          perform
          expect(blobstore).to have_received(:delete).with('fake-stale-blob-id')
          expect(blobstore).to_not have_received(:delete).with('fake-latest-blob-id')
        end

        it 'removes stale templates for the current instance from the database' do
          expect {
            perform
          }.to change {
            instance_model.refresh.rendered_templates_archives.map(&:blobstore_id)
          }.to(['fake-latest-blob-id'])
        end

        it 'does not affect rendered templates belonging to another instance' do
          other_instance_model = Models::Instance.make

          Models::RenderedTemplatesArchive.make(
            blobstore_id: 'fake-other-latest-blob-id',
            instance: other_instance_model,
          )

          expect {
            perform
          }.not_to change {
            other_instance_model.refresh.rendered_templates_archives.count
          }.from(1)
        end
      end
    end

    describe '#clean_all' do
      before { allow(blobstore).to receive(:delete) }

      def perform
        rendered_job_templates.clean_all
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'does nothing' do
          expect { perform }.to_not raise_error
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        before do
          Models::RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: instance_model,
            created_at: Time.new(2013, 02, 01),
          )

          Models::RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: instance_model,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'removes all rendered template blobs associated with an instance' do
          perform
          expect(blobstore).to have_received(:delete).with('fake-latest-blob-id')
          expect(blobstore).to have_received(:delete).with('fake-stale-blob-id')
        end

        it 'removes all rendered template archives from the database associated with an instance' do
          expect {
            perform
          }.to change { instance_model.refresh.rendered_templates_archives.count }.to(0)
        end

        it 'does not affect rendered templates belonging to another instance' do
          other_instance_model = Models::Instance.make

          Models::RenderedTemplatesArchive.make(
            instance: other_instance_model,
          )

          expect {
            perform
          }.not_to change {
            other_instance_model.refresh.rendered_templates_archives.count
          }.from(1)
        end
      end
    end
  end
end
