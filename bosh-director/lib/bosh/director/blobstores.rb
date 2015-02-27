module Bosh::Director
  class Blobstores
    attr_reader :blobstore

    def initialize(config)
      b_config = config.blobstore_config
      bd_config = config.backup_blobstore_config
      @blobstore = create_client(b_config)
      @backup_destination = create_client(bd_config) if bd_config
    end

    def backup_destination
      raise 'No backup destination configured' unless @backup_destination
      @backup_destination
    end

    private

    def create_client(hash)
      provider = hash.fetch('provider')
      options = hash.fetch('options')
      Bosh::Blobstore::Client.safe_create(provider, options)
    end
  end
end
