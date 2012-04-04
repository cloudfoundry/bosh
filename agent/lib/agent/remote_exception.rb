# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class RemoteException
    attr_reader :message, :backtrace, :blob, :blobstore_id

    def initialize(message, backtrace=nil, blob=nil)
      @message = message
      @backtrace = backtrace.nil? ? caller : backtrace
      @blob = blob
      @blobstore_id = store_blob if blob
    end

    # returns the blobstore id of the stored object, or an error
    # string which can be displayed
    def store_blob
      bsc_options  = Bosh::Agent::Config.blobstore_options
      bsc_provider = Bosh::Agent::Config.blobstore_provider

      blobstore = Bosh::Blobstore::Client.create(bsc_provider, bsc_options)

      logger.info("Uploading blob for '#{@message}' to blobstore")

      blobstore_id = nil
      blobstore_id = blobstore.create(@blob)

      blobstore_id
    rescue Bosh::Blobstore::BlobstoreError => e
      logger.warning("unable to upload blob for '#{@message}'")
      "error: unable to upload blob to blobstore: #{e.message}"
    end

    # Returns a hash of the [RemoteException] suitable to convert to json
    #
    # @return [Hash] [RemoteException] represented as a [Hash]
    def to_hash
      hash = {:message => @message}
      hash[:backtrace] = @backtrace
      hash[:blobstore_id] = @blobstore_id if @blob
      {:exception => hash}
    end

    def logger
      Bosh::Agent::Config.logger
    end

    def self.from(exception)
      blob = nil
      if exception.instance_of?(Bosh::Agent::MessageHandlerError)
        blob = exception.blob
      end
      self.new(exception.message, exception.backtrace, blob)
    end

  end
end
