module Bosh::Director
  module Blobstore

    class BlobstoreError < StandardError; end

    class NotFound < BlobstoreError; end

    class NotImplemented < BlobstoreError; end

  end
end
