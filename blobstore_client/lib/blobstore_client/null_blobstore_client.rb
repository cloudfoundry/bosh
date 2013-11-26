require 'securerandom'

module Bosh::Blobstore
  class NullBlobstoreClient
    def create(contents, id = nil)
      SecureRandom.uuid
    end

    def get(id, file = nil, options = nil)
      raise NotFound, "Blobstore object '#{id}' not found"
    end

    def delete(oid)
    end

    def exists?(oid)
      false
    end
  end
end
