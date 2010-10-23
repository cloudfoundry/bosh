require 'blobstore_client'

module Bosh::Agent
  module Message
    class CompilePackage
      attr_accessor :package_blobstore_id, :package_sha1
      attr_reader :blobstore_client

      def self.process(args)
        self.new(args).start
      end

      def initialize(args)
        bsc_options = Bosh::Agent::Config.blobstore_options
        @blobstore_client = Bosh::Blobstore::SimpleBlobstoreClient.new(bsc_options)
        @blobstore_id, @sha1 = args
      end

      def start
        # TODO refactor director to include package name and version
        # TODO get package from blob store
        # TODO unpack in temporary directory
        # TODO run packaging script and install to install location
        # TODO package up install location (define contract)
        # TODO push to blobstore
      end

    end
  end
end
