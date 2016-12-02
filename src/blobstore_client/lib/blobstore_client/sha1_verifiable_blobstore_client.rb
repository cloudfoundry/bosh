require 'digest/sha1'
require 'forwardable'

module Bosh
  module Blobstore
    class Sha1VerifiableBlobstoreClient < BaseClient
      extend Forwardable

      def initialize(client)
        @client = client
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
        actual_sha1   = Digest::SHA1.file(file_to_check.path).hexdigest
        unless expected_sha1 == actual_sha1
          raise BlobstoreError, "sha1 mismatch expected=#{expected_sha1} actual=#{actual_sha1}"
        end
      end
    end
  end
end
