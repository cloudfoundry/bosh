require "common/common"
require "time"

module Bosh::AwsCloud
  class InstanceManager
    include Helpers

    attr_reader :instance
    attr_reader :instance_params
    attr_reader :elbs

    def initialize(region, registry, az_selector=nil)
      @region = region
      @registry = registry
      @logger = Bosh::Clouds::Config.logger
      @az_selector = az_selector
      @instance_params = {count: 1}
    end

    def create(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment, options)
      @instance_params[:image_id] = stemcell_id
      @instance_params[:instance_type] = resource_pool["instance_type"]
      set_user_data_parameter(networks_spec)
      set_key_name_parameter(resource_pool["key_name"], options["aws"]["default_key_name"])
      set_security_groups_parameter(networks_spec, options["aws"]["default_security_groups"])
      set_vpc_parameters(networks_spec)
      set_availability_zone_parameter(
          (disk_locality || []).map { |volume_id| @region.volumes[volume_id].availability_zone.to_s },
          resource_pool["availability_zone"],
          (@instance_params[:subnet].availability_zone_name if @instance_params[:subnet])
      )
      
      @logger.info("Creating new instance with: #{instance_params.inspect}")
      
      if resource_pool["spot_bid_price"]
        @logger.info("Launching spot instance...")
        security_group_ids = []
        @region.security_groups.each do |group|
           security_group_ids << group.security_group_id if @instance_params[:security_groups].include?(group.name)
        end 
        spot_request_spec = create_spot_request_spec(instance_params, security_group_ids, resource_pool["spot_bid_price"])
        @logger.debug("Requesting spot instance with: #{spot_request_spec.inspect}")
        spot_instance_requests = @region.client.request_spot_instances(spot_request_spec) 
        @logger.debug("Got spot instance requests: #{spot_instance_requests.inspect}") 
        
        wait_for_spot_instance_request_to_be_active spot_instance_requests
      else
        # Retry the create instance operation a couple of times if we are told that the IP
        # address is in use - it can happen when the director recreates a VM and AWS
        # is too slow to update its state when we have released the IP address and want to
        # realocate it again.
        errors = [AWS::EC2::Errors::InvalidIPAddress::InUse]
        Bosh::Common.retryable(sleep: instance_create_wait_time, tries: 10, on: errors) do |tries, error|
          @logger.info("Launching on demand instance...") 
          @logger.warn("IP address was in use: #{error}") if tries > 0
          @instance = @region.instances.create(instance_params)
        end
      end 

      # We need to wait here for the instance to be running, as if we are going to
      # attach to a load balancer, the instance must be running.
      # If we time out, it is because the instance never gets from state running to started,
      # so we signal the director that it is ok to retry the operation. At the moment this
      # forever (until the operation is cancelled by the user).
      begin
        @logger.info("Waiting for instance to be ready...") 
        ResourceWait.for_instance(instance: instance, state: :running)
      rescue Bosh::Common::RetryCountExceeded => e
        @logger.warn("timed out waiting for #{instance.id} to be running")
        raise Bosh::Clouds::VMCreationFailed.new(true)
      end

      @elbs = resource_pool['elbs']
      attach_to_load_balancers if elbs

      instance
    end

    def create_spot_request_spec(instance_params, security_group_ids, spot_price) {
      spot_price: "#{spot_price}",
      instance_count: 1,
      valid_until: "#{(Time.now + 20*60).utc.iso8601}",
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
            groups: security_group_ids,
            device_index: 0,
            private_ip_address: instance_params[:private_ip_address]
          } 
        ]
      }
    }
    end

    def wait_for_spot_instance_request_to_be_active(spot_instance_requests)
      # Query the spot request state until it becomes "active".
      # This can result in the errors listed below; this is normally because AWS has 
      # been slow to update its state so the correct response is to wait a bit and try again.
      errors = [AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound]
      Bosh::Common.retryable(sleep: instance_create_wait_time*2, tries: 20, on: errors) do |tries, error|
          @logger.warn("Retrying after expected error: #{error}") if error
          @logger.debug("Checking state of spot instance requests...")
          spot_instance_request_ids = spot_instance_requests[:spot_instance_request_set].map { |r| r[:spot_instance_request_id] } 
          response = @region.client.describe_spot_instance_requests(:spot_instance_request_ids => spot_instance_request_ids)
          statuses = response[:spot_instance_request_set].map { |rr| rr[:state] }
          @logger.debug("Spot instance request states: #{statuses.inspect}")
          if statuses.all? { |s| s == 'active' }
             @logger.info("Spot request instances fulfilled: #{response.inspect}")
             instance_id = response[:spot_instance_request_set].map { |rr| rr[:instance_id] }[0]
             @instance = @region.instances[instance_id]
          end
      end
    end

    def terminate(instance_id, fast=false)
      @instance = @region.instances[instance_id]

      remove_from_load_balancers

      begin
        instance.terminate
      rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
        @logger.info("Failed to terminate instance because it was not found: #{e.inspect}")
        raise Bosh::Clouds::VMNotFound, "VM `#{instance_id}' not found"
      ensure
        @logger.info("Deleting instance settings for '#{instance_id}'")
        @registry.delete_settings(instance_id)
      end

      if fast
        TagManager.tag(instance, "Name", "to be deleted")
        @logger.info("Instance #{instance_id} marked to deletion")
        return
      end

      begin
        @logger.info("Deleting instance '#{instance.id}'")
        ResourceWait.for_instance(instance: instance, state: :terminated)
      rescue AWS::EC2::Errors::InvalidInstanceID::NotFound
        # It's OK, just means that instance has already been deleted
      end
    end

    # Soft reboots EC2 instance
    # @param [String] instance_id EC2 instance id
    def reboot(instance_id)
      instance = @region.instances[instance_id]

      # There is no trackable status change for the instance being
      # rebooted, so it's up to CPI client to keep track of agent
      # being ready after reboot.
      # Due to this, we can't deregister the instance from any load
      # balancers it might be attached to, and reattach once the
      # reboot is complete, so we just have to let the load balancers
      # take the instance out of rotation, and put it back in once it
      # is back up again.
      instance.reboot
    end

    def attach_to_load_balancers
      elb = AWS::ELB.new

      elbs.each do |load_balancer|
        lb = elb.load_balancers[load_balancer]
        lb.instances.register(instance)
      end
    end

    # Determines if the instance exists.
    # @param [String] instance_id EC2 instance id
    def has_instance?(instance_id)
      instance = @region.instances[instance_id]

      instance.exists? && instance.status != :terminated
    end

    def remove_from_load_balancers
      elb = AWS::ELB.new

      elb.load_balancers.each do |load_balancer|
        begin
          load_balancer.instances.deregister(instance)
        rescue AWS::ELB::Errors::InvalidInstance
          # ignore this, as it just means it wasn't registered
        end
      end
    end

    def set_key_name_parameter(resource_pool_key_name, default_aws_key_name)
      key_name = resource_pool_key_name || default_aws_key_name
      instance_params[:key_name] = key_name unless key_name.nil?
    end

    def set_security_groups_parameter(networks_spec, default_security_groups)
      security_group_names = extract_security_group_names(networks_spec)
      if security_group_names.empty?
        instance_params[:security_groups] = default_security_groups
      else
        instance_params[:security_groups] = security_group_names
      end
    end

    def set_vpc_parameters(network_spec)
      manual_network_spec = network_spec.values.select { |spec| ["manual", nil].include? spec["type"] }.first
      if manual_network_spec
        instance_params[:private_ip_address] = manual_network_spec["ip"]
      end
      
      subnet_network_spec = network_spec.values.select { |spec| 
        ["manual", nil, "dynamic"].include?(spec["type"]) && 
        spec.fetch("cloud_properties", {}).has_key?("subnet")
      }.first
      if subnet_network_spec
          instance_params[:subnet] = @region.subnets[subnet_network_spec["cloud_properties"]["subnet"]]
      end      
    end

    def set_availability_zone_parameter(volume_zones, resource_pool_zone, subnet_zone)
      availability_zone = @az_selector.common_availability_zone(volume_zones, resource_pool_zone, subnet_zone)
      instance_params[:availability_zone] = availability_zone if availability_zone
    end

    def set_user_data_parameter(networks_spec)
      user_data = {registry: {endpoint: @registry.endpoint}}

      spec_with_dns = networks_spec.values.select { |spec| spec.has_key? "dns" }.first
      user_data[:dns] = {nameserver: spec_with_dns["dns"]} if spec_with_dns

      @instance_params[:user_data] = Yajl::Encoder.encode(user_data)
    end

    private

    def instance_create_wait_time; 30; end
  end
end