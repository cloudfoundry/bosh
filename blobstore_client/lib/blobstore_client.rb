# Copyright (c) 2009-2012 VMware, Inc.

module Bosh; module Blobstore; end; end

require "common/common"
require "blobstore_client/version"
require "blobstore_client/errors"

require "blobstore_client/client"
require "blobstore_client/base"
require "blobstore_client/simple_blobstore_client"
require "blobstore_client/s3_blobstore_client"
require "blobstore_client/local_client"
require "blobstore_client/atmos_blobstore_client"

module Bosh
  module Blobstore
    class Client

      PROVIDER_MAP = {
        "simple" => SimpleBlobstoreClient,
        "s3" => S3BlobstoreClient,
        "atmos" => AtmosBlobstoreClient,
        "local" => LocalClient
      }

      def self.create(blobstore_provider, options = {})
        provider = PROVIDER_MAP[blobstore_provider]

        unless provider
          providers = PROVIDER_MAP.keys.sort.join(", ")
          raise BlobstoreError,
            "Invalid client provider, available providers are: #{providers}"
        end

        provider.new(options)
      end

    end
  end
end
