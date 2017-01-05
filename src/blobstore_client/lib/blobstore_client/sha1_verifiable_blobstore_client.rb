require 'digest/sha1'
require 'forwardable'
require 'open3'


module Bosh
  module Blobstore
    class Sha1VerifiableBlobstoreClient < BaseClient
      extend Forwardable

      def initialize(client, multidigest_path)
        @client = client
        @multidigest_path = multidigest_path
      end

      def get(id, file = nil, options = {})
        if options.has_key?(:sha1)
          expected_sha1 = options[:sha1]
          raise ArgumentError, 'sha1 must not be nil' unless expected_sha1
        end

        result_file = @client.get(id, file, options)

        if expected_sha1
          # Blobstore clients either modify passed in file
          # or return new temporary file
          check_sha1(expected_sha1, file || result_file)
        end

        result_file
      end

      def_delegators :@client, :create, :delete, :exists?

      private

      def check_sha1(expected_sha1, file_to_check)
        expected_sha1 = expected_sha1
        out, err, status = Open3.capture3("#{@multidigest_path} verify-multi-digest #{file_to_check.path} #{expected_sha1}")
        unless status.exitstatus == 0
          raise BlobstoreError, "sha1 mismatch expected=#{expected_sha1}, error: #{err}"
        end
      end
    end
  end
end
