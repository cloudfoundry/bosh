# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class Client

    attr_accessor :id

    def initialize(service_name, client_id, options = {})
      @service_name = service_name
      @client_id = client_id
      @nats_rpc = Config.nats_rpc
      @timeout = options[:timeout] || 30
      @logger = Config.logger
      @retry_methods = options[:retry_methods] || {}

      if options[:credentials]
        @encryption_handler =
          Bosh::EncryptionHandler.new(@client_id, options[:credentials])
      end

      @resource_manager = Api::ResourceManager.new
    end

    def method_missing(method_name, *args)
      retries = @retry_methods[method_name] || 0
      begin
        handle_method(method_name, args)
      rescue RpcTimeout
        if retries > 0
          retries -= 1
          retry
        end
        raise
      end
    end

    def wait_until_ready(deadline = 300)
      old_timeout = @timeout
      @timeout = 1.0
      @deadline = Time.now.to_i + deadline

      begin
        ping
      rescue RpcTimeout
        if @deadline - Time.now.to_i > 0
          retry
        else
          raise RpcTimeout,
                "Timed out pinging to #{@client_id} after #{deadline} seconds"
        end
      ensure
        @timeout = old_timeout
      end
    end

    def handle_method(method_name, args)
      result = {}
      result.extend(MonitorMixin)

      cond = result.new_cond
      timeout_time = Time.now.to_f + @timeout

      request = {:method => method_name, :arguments => args}

      if @encryption_handler
        @logger.info("Request: #{request}")
        request = {"encrypted_data" => @encryption_handler.encrypt(request)}
        request["session_id"] = @encryption_handler.session_id
      end

      recipient = "#{@service_name}.#{@client_id}"

      request_id = @nats_rpc.send_request(recipient, request) do |response|
        if @encryption_handler
          begin
            response = @encryption_handler.decrypt(response["encrypted_data"])
          rescue Bosh::EncryptionHandler::CryptError => e
            # TODO: that's not really a remote exception, should we just raise?
            response["exception"] = "CryptError: #{e.inspect} #{e.backtrace}"
          end
          @logger.info("Response: #{response}")
        end

        result.synchronize do
          inject_compile_log(response)
          result.merge!(response)
          cond.signal
        end
      end

      result.synchronize do
        while result.empty?
          timeout = timeout_time - Time.now.to_f
          unless timeout > 0
            @nats_rpc.cancel_request(request_id)
            raise RpcTimeout,
                  "Timed out sending `#{method_name}' to #{@client_id} " +
                  "after #{@timeout} seconds"
          end
          cond.wait(timeout)
        end
      end

      if result.has_key?("exception")
        raise RpcRemoteException, format_exception(result["exception"])
      end

      result["value"]
    end

    # Returns formatted exception information
    # @param [Hash|#to_s] exception Serialized exception
    # @return [String]
    def format_exception(exception)
      return exception.to_s unless exception.is_a?(Hash)

      msg = exception["message"].to_s

      if exception["backtrace"]
        msg += "\n"
        msg += Array(exception["backtrace"]).join("\n")
      end

      if exception["blobstore_id"]
        blob = download_and_delete_blob(exception["blobstore_id"])
        msg += "\n"
        msg += blob.to_s
      end

      msg
    end

    private

    # the blob is removed from the blobstore once we have fetched it,
    # but if there is a crash before it is injected into the response
    # and then logged, there is a chance that we lose it
    def inject_compile_log(response)
      if response["value"] && response["value"].is_a?(Hash) &&
        response["value"]["result"].is_a?(Hash) &&
        blob_id = response["value"]["result"]["compile_log_id"]
        compile_log = download_and_delete_blob(blob_id)
        response["value"]["result"]["compile_log"] = compile_log
      end
    end

    # Downloads blob and ensures it's deleted from the blobstore
    # @param [String] blob_id Blob id
    # @return [String] Blob contents
    def download_and_delete_blob(blob_id)
      # TODO: handle exceptions
      # (no reason to fail completely if blobstore doesn't work)
      blob = @resource_manager.get_resource(blob_id)
      blob
    ensure
      @resource_manager.delete_resource(blob_id)
    end

  end
end
