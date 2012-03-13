# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class Client

    class TimeoutException < StandardError; end

    attr_accessor :id

    def initialize(service_name, client_id, options = {})
      @service_name = service_name
      @client_id = client_id
      @nats_rpc = Config.nats_rpc
      @timeout = options[:timeout] || 30
      @logger = Config.logger
      @retry_methods = options[:retry_methods] || {}

      if options[:credentials]
        @encryption_handler = Bosh::EncryptionHandler.new(@client_id, options[:credentials])
      end
    end

    def method_missing(method_name, *args)
      retries = @retry_methods[method_name] || 0
      begin
        handle_method(method_name, args)
      rescue TimeoutException
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
      rescue TimeoutException
        if @deadline - Time.now.to_i > 0
          retry
        else
          raise TimeoutException, "Timed out pinging to #{@client_id} after #{deadline} seconds"
        end
      ensure
        @timeout = old_timeout
      end

    end

    private
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

      request_id = @nats_rpc.send("#{@service_name}.#{@client_id}", request) do |response|
        if @encryption_handler
          begin
            response = @encryption_handler.decrypt(response["encrypted_data"])
          rescue Bosh::EncryptionHandler::CryptError => e
            response["exception"] = "CryptError: #{e.inspect} #{e.backtrace}"
          end
          @logger.info("Response: #{response}")
        end

        result.synchronize do
          result.merge!(response)
          cond.signal
        end
      end

      result.synchronize do
        while result.empty?
          timeout = timeout_time - Time.now.to_f
          unless timeout > 0
            @nats_rpc.cancel(request_id)
            raise TimeoutException, "Timed out sending #{method_name} to #{@client_id} after #{@timeout} seconds"
          end
          cond.wait(timeout)
        end
      end

      raise result["exception"] if result.has_key?("exception")
      result["value"]
    end

  end
end
