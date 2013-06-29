# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class Blobstores

    attr_reader :blobstore, :backup_destination

    def initialize(config)
      @blobstore = create_client(config.hash.fetch('blobstore'))
      @backup_destination = create_client(config.hash.fetch('backup_destination'))
    end

    private

    def create_client(hash)
      provider = hash.fetch('provider')
      options = hash.fetch('options')

      Bosh::Blobstore::Client.create(provider, options)
    end
  end
end
