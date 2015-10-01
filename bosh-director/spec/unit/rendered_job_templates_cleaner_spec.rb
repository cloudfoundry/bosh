require 'spec_helper'
require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  describe RenderedJobTemplatesCleaner do
    subject(:rendered_job_templates) { described_class.new(instance_model, blobstore, logger) }
    let(:instance_model) { Models::Instance.make }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

    describe '#clean' do
      def perform
        rendered_job_templates.clean
      end

      let(:stale_archive) do
        Models::RenderedTemplatesArchive.make(
          blobstore_id: 'fake-blob-id',
          instance: instance_model,
          created_at: Time.new(2013, 02, 01),
        )
      end

      it 'removes *stale* archives from the blobstore and then from the database' do
        allow(instance_model).to receive(:stale_rendered_templates_archives).and_return([stale_archive])
        expect(blobstore).to receive(:delete).with('fake-blob-id').ordered
        expect(stale_archive).to receive(:delete).with(no_args).ordered
        perform
      end

      it 'removes *stale* archives from the database even if the archives are not in the blobstore' do
        allow(instance_model).to receive(:stale_rendered_templates_archives).and_return([stale_archive])
        expect(blobstore).to receive(:delete).with('fake-blob-id').and_raise Bosh::Blobstore::NotFound
        expect(logger).to receive(:debug).with("Blobstore#delete error: Bosh::Blobstore::NotFound, will ignore this error and delete the db record")
        expect(stale_archive).to receive(:delete).with(no_args)
        perform
      end
    end

    describe '#clean_all' do
      def perform
        rendered_job_templates.clean_all
      end

      let(:stale_archive) do
        Models::RenderedTemplatesArchive.make(
          blobstore_id: 'fake-blob-id',
          instance: instance_model,
          created_at: Time.new(2013, 02, 01),
        )
      end

      it 'removes *all* archives from the blobstore and then from the database' do
        allow(instance_model).to receive(:rendered_templates_archives).and_return([stale_archive])
        expect(blobstore).to receive(:delete).with('fake-blob-id').ordered
        expect(stale_archive).to receive(:delete).with(no_args).ordered
        perform
      end

      it 'removes *all* archives from the database even if the archives are not in the blobstore' do
        allow(instance_model).to receive(:rendered_templates_archives).and_return([stale_archive])
        expect(blobstore).to receive(:delete).with('fake-blob-id').and_raise Bosh::Blobstore::NotFound
        expect(logger).to receive(:debug).with("Blobstore#delete error: Bosh::Blobstore::NotFound, will ignore this error and delete the db record")
        expect(stale_archive).to receive(:delete).with(no_args)
        perform
      end
    end
  end
end
