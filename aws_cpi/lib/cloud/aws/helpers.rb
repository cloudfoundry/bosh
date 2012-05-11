# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud

  module Helpers

    DEFAULT_TIMEOUT = 3600

    ##
    # Raises CloudError exception
    #
    def cloud_error(message)
      if @logger
        @logger.error(message)
      end
      raise Bosh::Clouds::CloudError, message
    end

    def wait_resource(resource, start_state,
                      target_state, state_method = :status,
                      timeout = DEFAULT_TIMEOUT)

      started_at = Time.now
      state = resource.send(state_method)
      desc = resource.to_s

      while state == start_state && state != target_state
        duration = Time.now - started_at

        if duration > timeout
          cloud_error("Timed out waiting for #{desc} " \
                      "to be #{target_state}")
        end

        if @logger
          @logger.debug("Waiting for #{desc} " \
                        "to be #{target_state} (#{duration})")
        end

        sleep(1)

        state = resource.send(state_method)
      end

      if state == target_state
        if @logger
          @logger.info("#{desc} is #{target_state} " \
                       "after #{Time.now - started_at}s")
        end
      else
        cloud_error("#{desc} is #{state}, " \
                    "expected to be #{target_state}")
      end
    end
  end
end

