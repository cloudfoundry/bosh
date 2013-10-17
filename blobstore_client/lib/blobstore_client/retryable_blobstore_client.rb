module Bosh
  module Blobstore
    class RetryableBlobstoreClient
      def initialize(client, retryable)
        @client = client
        @retryable = retryable
      end

      def get(*args)
        # BoshRetryable#retryer interface does not allow nil
        # as a successful return value; hence, we save off last result
        last_result = nil

        @retryable.retryer do
          last_result = @client.get(*args)
          true
        end

        last_result
      end
    end
  end
end
