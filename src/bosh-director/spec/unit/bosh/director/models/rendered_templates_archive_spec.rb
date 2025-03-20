require 'spec_helper'
require 'bosh/director/models/rendered_templates_archive'

module Bosh::Director::Models
  describe RenderedTemplatesArchive do
    it 'belongs to an instance' do
      expect(RenderedTemplatesArchive.associations).to include(:instance)
    end

    it 'tracks its blob id so it can be downloaded form the blobstore' do
      expect(RenderedTemplatesArchive.columns).to include(:blobstore_id)
    end

    it 'tracks its checksum so the blobstore download can be checked' do
      expect(RenderedTemplatesArchive.columns).to include(:sha1)
    end

    it 'tracks its content sha1 so that archives for the same job templates are not needlessly created' do
      expect(RenderedTemplatesArchive.columns).to include(:content_sha1)
    end

    it 'tracks when it was created so the most recent archive for an instance can be identified' do
      expect(RenderedTemplatesArchive.columns).to include(:created_at)
    end
  end
end
