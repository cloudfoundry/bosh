# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::CloudStackCloud

  module Helpers

    DEFAULT_STATE_TIMEOUT = 300 # Default timeout for target state (in seconds)
    MAX_RETRIES = 10 # Max number of retries
    DEFAULT_RETRY_TIMEOUT = 3 # Default timeout before retrying a call (in seconds)

    ##
    # Raises CloudError exception
    #
    # @param [String] message Message about what went wrong
    # @param [Exception] exception Exception to be logged (optional)
    def cloud_error(message, exception = nil)
      @logger.error(message) if @logger
      @logger.error(exception) if @logger && exception
      raise Bosh::Clouds::CloudError, message
    end

    def with_compute
      retries = 0
      begin
        yield
      rescue Excon::Errors::BadRequest => e
        badrequest = parse_api_response(e.response, "badRequest")
        details = badrequest.nil? ? "" : " (#{badrequest["message"]})"
        cloud_error("CloudStack API Bad Request#{details}. Check task debug log for details.", e)
      rescue Excon::Errors::InternalServerError => e
        unless retries >= MAX_RETRIES
          retries += 1
          @logger.debug("CloudStack API Internal Server error, retrying (#{retries})") if @logger
          sleep(DEFAULT_RETRY_TIMEOUT)
          retry
        end
        cloud_error("CloudStack API Internal Server error. Check task debug log for details.", e)
      end
    end

    ##
    # Parses and look ups for keys in an CloudStack response
    #
    # @param [Excon::Response] response Response from CloudStack API
    # @param [Array<String>] keys Keys to look up in response
    # @return [Hash] Contents at the first key found, or nil if not found
    def parse_api_response(response, *keys)
      unless response.body.empty?
        begin
          body = JSON.parse(response.body)
          key = keys.detect { |k| body.has_key?(k)}
          return body[key] if key
        rescue JSON::ParserError
          # do nothing
        end
      end
      nil
    end

    ##
    # Waits for a resource to be on a target state
    #
    # @param [Fog::Model] resource Resource to query
    # @param [Array<Symbol>] target_state Resource's state desired
    # @param [Symbol] state_method Resource's method to fetch state
    # @param [Boolean] allow_notfound true if resource could be not found
    # @param [Integer] time_out Time to wait for completion
    def wait_resource(resource, target_state, state_method = :state, allow_notfound = false, time_out = @state_timeout)

      started_at = Time.now
      desc = resource.class.name.split("::").last.to_s + " `" + resource.id.to_s + "'"
      target_state = Array(target_state)
      state_timeout = time_out || DEFAULT_STATE_TIMEOUT

      loop do
        task_checkpoint

        duration = Time.now - started_at

        if duration > state_timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state.join(", ")}")
        end

        if @logger
          @logger.debug("Waiting for #{desc} to be #{target_state.join(", ")} (#{duration}s)")
        end

        # If resource reload is nil, perhaps it's because resource went away
        # (ie: a destroy operation). Don't raise an exception if this is
        # expected (allow_notfound).
        if with_compute { resource.reload.nil? }
          break if allow_notfound
          cloud_error("#{desc}: Resource not found")
        else
          state =  with_compute { resource.send(state_method).to_s.downcase.to_sym }
        end

        # This is not a very strong convention, but some resources
        # have 'error', 'failed' and 'killed' states, we probably don't want to keep
        # waiting if we're in these states. Alternatively we could introduce a
        # set of 'loop breaker' states but that doesn't seem very helpful
        # at the moment
        if (state == :error || state == :failed || state == :killed) ||
           (resource.instance_of?(Fog::Compute::Cloudstack::Job) && state == :"2")
          cloud_error("#{desc} state is #{state}, expected #{target_state.join(", ")}")
        end

        break if target_state.include?(state)

        sleep(1)
      end

      if @logger
        total = Time.now - started_at
        @logger.info("#{desc} is now #{target_state.join(", ")}, took #{total}s")
      end
    end

    def wait_job(job)
      wait_resource(job, :"1", :job_status, false)
      job.job_result
    end

    def wait_job_volume(job)
      wait_resource(job, :"1", :job_status, false, @state_timeout_volume)
      job.job_result
    end

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

  end

end
