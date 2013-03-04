# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::OpenStackCloud
  class Connection
    include Helpers

    MAX_RETRYAFTER_TIME = 10 # Max number of seconds before retrying a call

    def initialize(service, params = {})
      @logger = Bosh::Clouds::Config.logger
      case service
        when :compute then @connection = Fog::Compute.new(params)
        when :image then @connection = Fog::Image.new(params)
        else cloud_error("Service #{service} not supported by OpenStack CPI")
      end
    end

    # Delegate all methods to Fog.
    def method_missing(method, *arguments, &block)
      return super unless @connection.respond_to?(method)

      begin
        @connection.send(method, *arguments, &block)
      rescue Excon::Errors::RequestEntityTooLarge => e
        # If we find a rate limit error, parse message, wait, and retry
        retried = false
        unless e.response.body.empty?
          begin
            message = JSON.parse(e.response.body)
            if message["overLimit"] && message["overLimit"]["retryAfter"]
              retryafter = message["overLimit"]["retryAfter"]
              wait_time = [MAX_RETRYAFTER_TIME, retryafter.to_i].min
              task_checkpoint
              @logger.debug("OpenStack API overLimit, waiting #{wait_time} " +
                            "seconds before retrying") if @logger
              sleep(wait_time)
              retried = true
              retry
            end
          rescue JSON::ParserError
            # do nothing
          end
        end
        raise e unless retried
      end
    end
  end
end