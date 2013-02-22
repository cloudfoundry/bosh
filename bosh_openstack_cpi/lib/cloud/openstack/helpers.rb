# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud

  module Helpers

    DEFAULT_TIMEOUT = 600 # Default timeout for target state (in seconds)

    ##
    # Raises CloudError exception
    #
    # @param [String] message Message about what went wrong
    def cloud_error(message)
      @logger.error(message) if @logger
      raise Bosh::Clouds::CloudError, message
    end

    ##
    # Waits for a resource to be on a target state
    #
    # @param [Fog::Model] resource Resource to query
    # @param [Symbol] target_state Resource's state desired
    # @param [Symbol] state_method Resource's method to fetch state
    # @param [Boolean] allow_notfound true if resource could be not found
    # @param [Integer] timeout Timeout for target state (in seconds)
    def wait_resource(resource, target_state, state_method = :status,
                      allow_notfound = false, timeout = DEFAULT_TIMEOUT)

      started_at = Time.now
      desc = resource.class.name.split("::").last.to_s + " `" +
             resource.id.to_s + "'"

      loop do
        task_checkpoint

        duration = Time.now - started_at

        if duration > timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state}")
        end

        if @logger
          @logger.debug("Waiting for #{desc} to be #{target_state} " \
                        "(#{duration}s)")
        end

        # If resource reload is nil, perhaps it's because resource went away
        # (ie: a destroy operation). Don't raise an exception if this is
        # expected (allow_notfound).
        if resource.reload.nil?
          break if allow_notfound
          cloud_error("#{desc}: Resource not found")
        else
          state = resource.send(state_method).downcase.to_sym
        end

        # This is not a very strong convention, but some resources
        # have 'error' and 'failed' states, we probably don't want to keep
        # waiting if we're in these states. Alternatively we could introduce a
        # set of 'loop breaker' states but that doesn't seem very helpful
        # at the moment
        if state == :error || state == :failed
          cloud_error("#{desc} state is #{state}, expected #{target_state}")
        end

        break if state == target_state

        sleep(1)
      end

      if @logger
        total = Time.now - started_at
        @logger.info("#{desc} is now #{target_state}, took #{total}s")
      end
    end

  end

end
