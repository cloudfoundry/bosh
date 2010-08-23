begin
  require ::File.expand_path('../../.bundle/environment', __FILE__)
  Bundler.require
rescue LoadError
  puts "Can't find bundler environment, please run rake bundler:install"
  Process.exit
end

module Bosh
  module Blobstore

  end
end

require "blobstore_client/client"
require "blobstore_client/simple_blobstore_client"

module Bosh
  module Blobstore
    class Client

      def self.create(provider, options)
        case provider
          when :simple
            SimpleBlobstoreClient.new(options)
          else
            raise "Invalid client provider"
        end
      end
       
    end
  end
end