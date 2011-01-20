module Bosh; module Blobstore; end; end

require "blobstore_client/version"
require "blobstore_client/errors"

require "blobstore_client/client"
require "blobstore_client/simple_blobstore_client"
require "blobstore_client/s3_blobstore_client"

module Bosh
  module Blobstore
    class Client
      def self.create(provider, options = { })

        case provider
        when "simple"
          SimpleBlobstoreClient.new(options)
        when "s3"
          S3BlobstoreClient.new(options)
        else
          raise "Invalid client provider, available providers are: 'simple', 's3'"
        end
      end
    end
  end
end
