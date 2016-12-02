# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Blobstore

    class BlobstoreError < StandardError; end
    class NotFound < BlobstoreError; end
    class NotImplemented < BlobstoreError; end

  end
end
