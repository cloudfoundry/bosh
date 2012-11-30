# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud

  module Helpers

    DEFAULT_TIMEOUT = 3600 # seconds

    ##
    # Raises CloudError exception
    #
    def cloud_error(message)
      if @logger
        @logger.error(message)
      end
      raise Bosh::Clouds::CloudError, message
    end

    def wait_resource(resource, target_state, state_method = :status,
                      timeout = DEFAULT_TIMEOUT)

      started_at = Time.now
      failures = 0
      desc = resource.to_s

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

        state = get_state_for(resource, state_method) do |error|
          @logger.error("#{error.message}: #{desc}")
          sleep(1)
          next
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

    private

    def get_state_for(resource, state_method)
      resource.send(state_method)
    rescue AWS::EC2::Errors::InvalidAMIID::NotFound,
        AWS::EC2::Errors::InvalidInstanceID::NotFound => e
      # ugly workaround for AWS race conditions:
      # 1) sometimes when we upload a stemcell and proceed to create a VM
      #    from it, AWS reports that the AMI is missing
      # 2) sometimes when we create a new EC2 instance, AWS reports that
      #    the instance it returns is missing
      # in both cases we just catch the exception, wait a little and retry...
      yield e
    end
  end
end

