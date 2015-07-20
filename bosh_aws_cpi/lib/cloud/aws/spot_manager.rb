require "common/common"
require "time"

module Bosh::AwsCloud
  class SpotManager
    TOTAL_WAIT_TIME_IN_SECONDS = 300
    RETRY_COUNT = 10

    def initialize(region)
      @region = region
      @logger = Bosh::Clouds::Config.logger
    end

    def create(instance_params, spot_bid_price)
      spot_request_spec = create_spot_request_spec(instance_params, spot_bid_price)
      @logger.debug("Requesting spot instance with: #{spot_request_spec.inspect}")

      begin
        @spot_instance_requests = @region.client.request_spot_instances(spot_request_spec)
        @logger.debug("Got spot instance requests: #{@spot_instance_requests.inspect}")
      rescue => e
        raise Bosh::Clouds::VMCreationFailed.new(false), e.inspect
      end

      request_spot_instance
    end

    private

    def request_spot_instance
      instance = nil

      # Query the spot request state until it becomes "active".
      # This can result in the errors listed below; this is normally because AWS has
      # been slow to update its state so the correct response is to wait a bit and try again.
      errors = [AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound]
      Bosh::Common.retryable(sleep: TOTAL_WAIT_TIME_IN_SECONDS/RETRY_COUNT, tries: RETRY_COUNT, on: errors) do |_, error|
        @logger.warn("Retrying after expected error: #{error}") if error

        status = spot_instance_request_status
        case status[:state]
          when 'failed'
            fail_spot_creation("VM spot instance creation failed: #{status.inspect}")
          when 'open'
            if status[:status] != nil && status[:status][:code] == 'price-too-low'
              fail_spot_creation("Cannot create VM spot instance because bid price is too low: #{status.inspect}")
            end
          when 'active'
            @logger.info("Spot request instances fulfilled: #{status.inspect}")
            instance = @region.instances[status[:instance_id]]
            true
        end
      end

      instance
    rescue Bosh::Common::RetryCountExceeded
      @logger.warn("Timed out waiting for spot request #{@spot_instance_requests.inspect} to be fulfilled")
      cancel_pending_spot_requests
      raise Bosh::Clouds::VMCreationFailed.new(true)
    end

    def create_spot_request_spec(instance_params, spot_price)
      spec = {
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
              device_index: 0,
              private_ip_address: instance_params[:private_ip_address]
            }
          ]
        }
      }
      security_groups = resolve_security_group_ids(instance_params[:security_groups])
      unless security_groups.empty?
        spec[:launch_specification][:network_interfaces][0][:groups] = security_groups
      end

      if instance_params[:block_device_mappings]
        spec[:launch_specification][:block_device_mappings] = instance_params[:block_device_mappings]
      end

      spec
    end

    def spot_instance_request_status
      @logger.debug('Checking state of spot instance requests...')
      response = @region.client.describe_spot_instance_requests(
        spot_instance_request_ids: spot_instance_request_ids
      )
      status = response[:spot_instance_request_set][0] # There is only ever 1
      @logger.debug("Spot instance request status: #{status.inspect}")
      status
    end

    def fail_spot_creation(message)
      @logger.error(message)
      cancel_pending_spot_requests
      raise Bosh::Clouds::VMCreationFailed.new(false), message
    end

    def spot_instance_request_ids
      @spot_instance_requests[:spot_instance_request_set].map { |r| r[:spot_instance_request_id] }
    end

    def cancel_pending_spot_requests
      @logger.warn("Failed to create spot instance: #{@spot_instance_requests.inspect}. Cancelling request...")
      cancel_response = @region.client.cancel_spot_instance_requests(
        spot_instance_request_ids: spot_instance_request_ids
      )
      @logger.warn("Spot cancel request returned: #{cancel_response.inspect}")
    end

    def resolve_security_group_ids(security_group_names)
      return [] unless security_group_names
      @region.security_groups.inject([]) do |security_group_ids, group|
        security_group_ids << group.security_group_id if security_group_names.include?(group.name)
        security_group_ids
      end
    end
  end
end
