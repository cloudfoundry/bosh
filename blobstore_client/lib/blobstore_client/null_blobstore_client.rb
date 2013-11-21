module Bosh::Blobstore
  class NullBlobstoreClient
    def create(contents, id = nil)
    end

    def get(id, file = nil, options = nil)
    end

    def delete(oid)
    end

    def exists?(oid)
    end
  end
end
