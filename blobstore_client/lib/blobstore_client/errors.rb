module Bosh
  module Blobstore

    class BlobstoreError < StandardError; end
    class NotFound < BlobstoreError; end
    
  end
end
