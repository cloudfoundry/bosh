require 'spec_helper'
require 'bosh/director/models/rendered_templates_archive'

module Bosh::Director::Models
  describe RenderedTemplatesArchive do
    it { expect(RenderedTemplatesArchive.ancestors).to include(Sequel::Model) }

    it 'belongs to an instance' do
      expect(RenderedTemplatesArchive.associations).to include(:instance)
    end

    it 'tracks its blob id so it can be downloaded form the blobstore' do
      expect(RenderedTemplatesArchive.columns).to include(:blob_id)
    end

    it 'tracks its checksum so the blobstore download can be checked' do
      expect(RenderedTemplatesArchive.columns).to include(:checksum)
    end

    it 'tracks when it was created so the most recent archive for an instance can be identified' do
      expect(RenderedTemplatesArchive.columns).to include(:created_at)
    end
  end
end
