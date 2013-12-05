require 'spec_helper'
require 'bosh/director/models/instance'

module Bosh::Director::Models
  describe Instance do
    subject { described_class.make }

    describe '#latest_rendered_templates_archive' do
      def perform
        subject.latest_rendered_templates_archive
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'returns nil' do
          expect(perform).to be_nil
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        let!(:latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: subject,
            created_at: Time.new(2013, 02, 01),
          )
        end

        let!(:not_latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: subject,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'returns most recent archive for associated instance' do
          expect(perform).to eq(latest)
        end

        it 'does not account for archives for other instances' do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-non-associated-latest-blob-id',
            instance: described_class.make,
            created_at: latest.created_at + 10_000,
          )

          expect(perform).to eq(latest)
        end
      end
    end

    describe '#stale_rendered_templates_archives' do
      def perform
        subject.stale_rendered_templates_archives
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'returns empty dataset' do
          expect(perform.to_a).to eq([])
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        let!(:latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: subject,
            created_at: Time.new(2013, 02, 01),
          )
        end

        let!(:not_latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: subject,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'returns non-latest archives for associated instance' do
          expect(perform.to_a).to eq([not_latest])
        end

        it 'does not include archives for other instances' do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-non-associated-latest-blob-id',
            instance: described_class.make,
            created_at: not_latest.created_at - 10_000,
          )

          expect(perform.to_a).to eq([not_latest])
        end
      end
    end
  end
end
