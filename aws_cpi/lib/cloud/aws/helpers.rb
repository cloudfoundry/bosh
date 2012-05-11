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

    # gets the availability zone the disk list is using
    def get_availability_zone(disks, default)
      availability_zone = nil

      # get availability_zone from disks
      if disks
        disks.each do |disk_cid|
          disk = @ec2.volumes[disk_cid]
          if availability_zone && availability_zone != disk.availability_zone
            raise "can't use multiple availability zones: '%s' and '%s'" %
              [availability_zone, disk.availability_zone]
          end
          availability_zone = disk.availability_zone
        end
      end

      if availability_zone && default && availability_zone != default
        raise "can't use multiple availability zones: '%s' and '%s'" %
          [availability_zone, default]
      elsif availability_zone.nil? && default
        availability_zone = default
      end

      # if we don't have an availability_zone by now, pick the default
      unless availability_zone
        availability_zone = Bosh::AwsCloud::Cloud::DEFAULT_AVAILABILITY_ZONE
      end

      availability_zone
    end

  end

end

