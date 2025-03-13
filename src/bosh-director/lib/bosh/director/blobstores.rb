module Bosh::Director
  class Blobstores
    attr_reader :blobstore

    def initialize(config)
      b_config = config.blobstore_config
      @blobstore = create_client(b_config)
    end

    private

    def create_client(hash)
      provider = hash.fetch('provider')
      options = hash.fetch('options')
      Bosh::Director::Blobstore::Client.safe_create(provider, options)
    end
  end
end
