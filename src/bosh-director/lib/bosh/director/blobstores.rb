module Bosh::Director
  class Blobstores
    PROVIDER_NAMES = %w[local s3cli gcscli davcli azurestoragecli]

    attr_reader :blobstore

    def initialize(config)
      @blobstore = create_client(config.blobstore_config)
    end

    private

    def create_client(hash)
      provider_string = hash.fetch('provider')
      options = hash.fetch('options')

      bare_client = create(provider_string, options)

      sha1_client = Blobstore::Sha1VerifyingClientWrapper.new(bare_client, Bosh::Director::Config.logger)
      retry_config = Bosh::Common::Retryable.new(tries: 6, sleep: 2.0, on: [Blobstore::BlobstoreError])
      Blobstore::RetryableClientWrapper.new(sha1_client, retry_config)
    end

    def create(provider_string, options = {})
      unless PROVIDER_NAMES.include?(provider_string)
        raise Blobstore::BlobstoreError,
              "Unknown client provider '#{provider_string}', " +
                "available providers are: #{PROVIDER_NAMES}"
      end

      Blobstore.const_get(provider_to_classname(provider_string)).new(options)
    end

    def provider_to_classname(provider_string)
      provider_string.capitalize + (provider_string == 'local' ? '' : 'Blobstore') + 'Client'
    end
  end
end
