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
        opts = Bosh::Common.symbolize_keys(options)

        # using S3 without credentials is a special case:
        # it is really the simple blobstore client with a bucket name
        if s3_read_only?(blobstore_provider, opts)
          raise BlobstoreError, "bucket name required" unless opts[:bucket]
          opts[:endpoint] ||= S3BlobstoreClient::ENDPOINT
          provider = SimpleBlobstoreClient
        else
          provider = PROVIDER_MAP[blobstore_provider]
        end

        unless provider
          providers = PROVIDER_MAP.keys.sort.join(", ")
          raise BlobstoreError,
            "Invalid client provider, available providers are: #{providers}"
        end

        provider.new(opts)
      end

      def self.s3_read_only?(blobstore_provider, options)
        blobstore_provider == "s3" &&
          options[:access_key_id].nil? && options[:secret_access_key].nil?
      end
    end
  end
end
