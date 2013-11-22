require 'spec_helper'
require 'bosh/director/rendered_job_templates'

module Bosh::Director
  describe RenderedJobTemplates do
    subject(:rendered_job_templates) do
      RenderedJobTemplates.new(instance, blobstore)
    end

    describe '#cleanup' do
      let(:stale_templates_blob_id) do
        'fake stale_templates_blob_id'
      end

      let(:blobstore) do
        Bosh::Blobstore::NullBlobstoreClient.new
      end

      let(:instance_model) do
        Models::Instance.make
      end

      let(:other_instance_model) do
        Models::Instance.make
      end

      let(:instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance', model: instance_model)
      end

      before do
        allow(blobstore).to receive(:delete)

        Models::RenderedTemplatesArchive.create(
          blob_id: 'latest blob id',
          instance: instance_model,
          created_at: Time.new(2013, 02, 01),
          checksum: 'current-fake-checksum',
        )

        Models::RenderedTemplatesArchive.create(
          blob_id: 'other-latest blob id',
          instance: other_instance_model,
          created_at: Time.new(2013, 01, 01),
          checksum: 'other-fake-checksum',
        )

        Models::RenderedTemplatesArchive.create(
          blob_id: stale_templates_blob_id,
          instance: instance_model,
          created_at: Time.new(2013, 01, 01),
          checksum: 'stale-fake-checksum',
        )
      end

      it 'removes stale templates for the current instance from the blobstore' do
        rendered_job_templates.cleanup

        expect(blobstore).to have_received(:delete).with(stale_templates_blob_id)
      end

      it 'removes stale templates for the current instance from the database' do
        expect {
          rendered_job_templates.cleanup
          instance.model.reload
        }.to change {
          archives = instance.model.rendered_templates_archives
          [archives.count, archives.first.blob_id]
        }.to([1, 'latest blob id'])
      end

      it 'does not affect rendered templates belonging to another instance' do
        expect {
          rendered_job_templates.cleanup
          other_instance_model.reload
        }.not_to change {
          other_instance_model.rendered_templates_archives.count
        }.from(1)
      end
    end
  end
end
