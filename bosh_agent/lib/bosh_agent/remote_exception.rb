module Bosh::Agent

  # Helper class to pass around and fromat exceptions in the agent
  # to the director
  class RemoteException
    attr_reader :message, :backtrace, :blob

    def initialize(message, backtrace=nil, blob=nil)
      @message = message
      @backtrace = backtrace.nil? ? caller : backtrace
      @blob = blob
    end

    # Stores the blob in the configured blobstore
    #
    # @return [String] blobstore id of the stored object, or an error
    # string which can be displayed instead of the blob
    def store_blob
      bsc_options  = Bosh::Agent::Config.blobstore_options
      bsc_provider = Bosh::Agent::Config.blobstore_provider

      blobstore = Bosh::Blobstore::Client.create(bsc_provider, bsc_options)

      logger.info("Uploading blob for '#{@message}' to blobstore")

      blobstore_id = nil
      blobstore_id = blobstore.create(@blob)

      blobstore_id
    rescue Bosh::Blobstore::BlobstoreError => e
      logger.warn("unable to upload blob for '#{@message}'")
      "error: unable to upload blob to blobstore: #{e.message}"
    end

    # Returns a hash of the [RemoteException] suitable to convert to json
    #
    # @return [Hash] [RemoteException] represented as a [Hash]
    def to_hash
      hash = {:message => @message}
      hash[:backtrace] = @backtrace
      hash[:blobstore_id] = store_blob if @blob
      {:exception => hash}
    end

    def logger
      Bosh::Agent::Config.logger
    end

    # Helper class method that creates a [Bosh::Agent::RemoteException]
    # from an [Exception]
    #
    # @return [Bosh::Agent::RemoteException]
    def self.from(exception)
      blob = nil
      if exception.instance_of?(Bosh::Agent::MessageHandlerError)
        blob = exception.blob
      end
      self.new(exception.message, exception.backtrace, blob)
    end

  end
end
