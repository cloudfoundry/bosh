require "common/common"
require "time"

module Bosh::AwsCloud
  class SpotManager

    def initialize(region)
      @region = region
      @logger = Bosh::Clouds::Config.logger
    end

    def create(instance_params, spot_bid_price)
	    spot_request_spec = create_spot_request_spec(instance_params, spot_bid_price)
	    @logger.debug("Requesting spot instance with: #{spot_request_spec.inspect}")
	    
	    spot_instance_requests = @region.client.request_spot_instances(spot_request_spec) 
	    @logger.debug("Got spot instance requests: #{spot_instance_requests.inspect}") 
	    
	    wait_for_spot_instance_request_to_be_active spot_instance_requests

	    @instance
    end

    def wait_for_spot_instance_request_to_be_active(spot_instance_requests)
      spot_instance_request_ids = []
      begin
        # Query the spot request state until it becomes "active".
        begin
          # This can result in the errors listed below; this is normally because AWS has 
          # been slow to update its state so the correct response is to wait a bit and try again.
          errors = [AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound]
          Bosh::Common.retryable(sleep: (total_spot_instance_request_wait_time/10), tries: 10, on: errors) do |tries, error|
              @logger.warn("Retrying after expected error: #{error}") if error
              @logger.debug("Checking state of spot instance requests...")
              spot_instance_request_ids = spot_instance_requests[:spot_instance_request_set].map { |r| r[:spot_instance_request_id] } 
              response = @region.client.describe_spot_instance_requests(:spot_instance_request_ids => spot_instance_request_ids)
              status = response[:spot_instance_request_set][0] #There is only ever 1
              @logger.debug("Spot instance request status: #{status.inspect}")

              # Failure states+status.  If any of these occur we should give up, since waiting won't help
              if status[:state] == 'failed' 
                @logger.error("VM spot instance creation failed: #{status.inspect}")
                raise Bosh::Clouds::VMCreationFailed.new(false), "VM spot instance creation failed: #{status.inspect}"
              end
              if status[:state] == 'open'
                if status[:status] != nil and status[:status][:code] == "price-too-low"
                  @logger.error("Cannot create VM spot instance because bid price is too low: #{status.inspect}")
                  raise Bosh::Clouds::VMCreationFailed.new(false), "VM spot instance creation failed because bid price is too low: #{status.inspect}"
                end
              end
              
              # Success!  We have a VM; lets use it
              if status[:state] == 'active'
                 @logger.info("Spot request instances fulfilled: #{response.inspect}")
                 instance_id = status[:instance_id]
                 @instance = @region.instances[instance_id]
                 return true
              end
          end
        rescue Bosh::Common::RetryCountExceeded => e
          @logger.warn("Timed out waiting for spot request #{spot_instance_requests.inspect} to be fulfilled")
          raise Bosh::Clouds::VMCreationFailed.new(true)
        end
      rescue Exception => e
        #Make sure we have cancelled the spot request
        @logger.warn("Failed to create spot instance: #{spot_instance_requests.inspect}.  Cancelling request...")
        cancel_response = @region.client.cancel_spot_instance_requests(:spot_instance_request_ids => spot_instance_request_ids)
        @logger.warn("Spot cancel request returned: #{cancel_response.inspect}")
        raise e
      end
    end

    private

    def create_spot_request_spec(instance_params, spot_price) {
      spot_price: "#{spot_price}",
      instance_count: 1,
      launch_specification: {
        image_id: instance_params[:image_id],
        key_name: instance_params[:key_name],
        instance_type: instance_params[:instance_type],
        user_data: Base64.encode64(instance_params[:user_data]),
        placement: {
          availability_zone: instance_params[:availability_zone]
        },
        network_interfaces: [ 
          { 
            subnet_id: instance_params[:subnet].subnet_id,
            groups: resolve_security_group_ids(instance_params[:security_groups]),
            device_index: 0,
            private_ip_address: instance_params[:private_ip_address]
          } 
        ]
      }
    }
    end

    def resolve_security_group_ids(security_group_names)
		security_group_ids = []
		@region.security_groups.each do |group|
		   security_group_ids << group.security_group_id if security_group_names.include?(group.name)
		end
		security_group_ids
    end

    # total time to wait for a spot instance request to be fulfilled - 300 = 5 minutes
    def total_spot_instance_request_wait_time; 300; end 
  end
end
