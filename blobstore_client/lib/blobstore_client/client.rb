module Bosh
  module Blobstore
    class Client
      PROVIDER_NAMES = %w[dav simple s3 swift local]

      def self.create(blobstore_provider, options = {})
        unless PROVIDER_NAMES.include?(blobstore_provider)
          raise BlobstoreError,
            "Unknown client provider '#{blobstore_provider}', " +
            "available providers are: #{PROVIDER_NAMES}"
        end
        blobstore_client_constantize(blobstore_provider).new(options)
      end

      def self.safe_create(provider, options = {})
        wrapped_client = create(provider, options)
        sha1_client    = Sha1VerifiableBlobstoreClient.new(wrapped_client)
        retryable      = Retryable.new(tries: 6, sleep: 2.0, on: [BlobstoreError])
        RetryableBlobstoreClient.new(sha1_client, retryable)
      end

      private

      def self.blobstore_client_constantize(base_string)
        class_string = base_string.capitalize + (base_string == 'local' ? '' : 'Blobstore') + 'Client'
        Bosh::Blobstore.const_get class_string
      end
    end
  end
end
