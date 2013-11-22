require 'spec_helper'
require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  describe RenderedJobTemplatesCleaner do
    subject(:rendered_job_templates) { described_class.new(instance, blobstore) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
    let(:blobstore) { Bosh::Blobstore::NullBlobstoreClient.new }

    describe '#cleanup' do
      before { instance.stub(model: instance_model) }
      let(:instance_model) { Models::Instance.make }

      before { allow(blobstore).to receive(:delete) }

      before do
        Models::RenderedTemplatesArchive.create(
          blob_id: 'fake-latest-blob-id',
          instance: instance_model,
          created_at: Time.new(2013, 02, 01),
          checksum: 'current-fake-checksum',
        )

        Models::RenderedTemplatesArchive.create(
          blob_id: 'fake-stale-blob-id',
          instance: instance_model,
          created_at: Time.new(2013, 01, 01),
          checksum: 'stale-fake-checksum',
        )
      end

      it 'removes stale templates for the current instance from the blobstore' do
        rendered_job_templates.cleanup
        expect(blobstore).to have_received(:delete).with('fake-stale-blob-id')
        expect(blobstore).to_not have_received(:delete).with('fake-latest-blob-id')
      end

      it 'removes stale templates for the current instance from the database' do
        expect {
          rendered_job_templates.cleanup
        }.to change {
          instance.model.refresh.rendered_templates_archives.map(&:blob_id)
        }.to(['fake-latest-blob-id'])
      end

      it 'does not affect rendered templates belonging to another instance' do
        other_instance_model = Models::Instance.make

        Models::RenderedTemplatesArchive.create(
          blob_id: 'fake-other-latest-blob-id',
          instance: other_instance_model,
          created_at: Time.new(1990, 01, 01),
          checksum: 'fake-other-fake-checksum',
        )

        expect {
          rendered_job_templates.cleanup
        }.not_to change {
          other_instance_model.refresh.rendered_templates_archives.count
        }.from(1)
      end
    end
  end
end
