require 'forwardable'

module Bosh
  module Blobstore
    class RetryableBlobstoreClient < BaseClient
      extend Forwardable

      def initialize(client, retryable)
        @client = client
        @retryable = retryable
      end

      def get(id, file = nil, options = {})
        # BoshRetryable#retryer interface does not allow nil
        # as a successful return value; hence, we save off last result
        last_result = nil

        @retryable.retryer do
          last_result = @client.get(id, file, options)
          true
        end

        last_result
      end

      def_delegators :@client, :create, :delete, :exists?, :sign,
                     :signing_enabled?, :credential_properties,
                     :required_credential_properties_list, :redacted_credential_properties_list,
                     :can_sign_urls?, :signed_url_encryption_headers, :encryption?,
                     :put_headers, :put_headers?
    end
  end
end
