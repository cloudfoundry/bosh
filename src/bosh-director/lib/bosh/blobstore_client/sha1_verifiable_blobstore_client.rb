require 'digest/sha1'
require 'forwardable'
require 'open3'

module Bosh
  module Blobstore
    class Sha1VerifiableBlobstoreClient < BaseClient
      extend Forwardable

      def initialize(client, logger)
        @client = client
        @multi_digest_verifier = Bosh::Director::BoshDigest::MultiDigest.new(logger)
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

      def_delegators :@client, :create, :delete, :exists?, :sign,
                     :signing_enabled?, :credential_properties,
                     :required_credential_properties_list, :redacted_credential_properties_list,
                     :can_sign_urls?

      private

      def check_sha1(expected_sha1, file_to_check)
        begin
          @multi_digest_verifier.verify(file_to_check.path, expected_sha1)
        rescue Bosh::Director::BoshDigest::ShaMismatchError => e
          raise Bosh::Blobstore::BlobstoreError.new(e)
        end
      end
    end
  end
end
