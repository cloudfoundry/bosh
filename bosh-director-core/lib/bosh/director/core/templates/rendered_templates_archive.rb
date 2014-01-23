require 'bosh/director/core/templates'

module Bosh::Director::Core::Templates
  class RenderedTemplatesArchive
    attr_reader :blobstore_id, :sha1

    def initialize(blobstore_id, sha1)
      @blobstore_id = blobstore_id
      @sha1 = sha1
    end

    def spec
      { 'blobstore_id' => @blobstore_id, 'sha1' => @sha1 }
    end
  end
end
