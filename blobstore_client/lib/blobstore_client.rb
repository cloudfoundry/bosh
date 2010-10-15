
module Bosh
  module Blobstore

  end
end

require "base64"

require "httpclient"

require "blobstore_client/client"
require "blobstore_client/simple_blobstore_client"

module Bosh
  module Blobstore
    class Client

      def self.create(provider, options)
        case provider
          when "simple"
            SimpleBlobstoreClient.new(options)
          else
            raise "Invalid client provider"
        end
      end

    end
  end
end
