module Bosh::AwsCloud
  class InstanceManager
    include Helpers

    attr_reader :instance_params

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
          (disk_locality || []).map { |volume_id| @region.volumes[volume_id].availability_zone },
          resource_pool["availability_zone"],
          (@instance_params[:subnet].availability_zone_name if @instance_params[:subnet])
      )

      @logger.info("Creating new instance with: #{instance_params.inspect}")
      @region.instances.create instance_params
    end

    def terminate(instance_id)
      instance = @region.instances[instance_id]

      instance.terminate

      begin
        # TODO: should this be done before or after deleting VM?
        @logger.info("Deleting instance settings for `#{instance.id}'")
        @registry.delete_settings(instance.id)

        @logger.info("Deleting instance `#{instance.id}'")
        wait_resource(instance, :terminated)
      rescue AWS::EC2::Errors::InvalidInstanceID::NotFound
        # It's OK, just means that instance has already been deleted
      end
    end

    # Soft reboots EC2 instance
    # @param [AWS::EC2::Instance] instance EC2 instance
    def reboot(instance_id)
      instance = @region.instances[instance_id]

      # There is no trackable status change for the instance being
      # rebooted, so it's up to CPI client to keep track of agent
      # being ready after reboot.
      instance.reboot
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
      manual_network_spec = network_spec.values.select{ |spec| ["manual", nil].include? spec["type"] }.first
      if manual_network_spec
        instance_params[:subnet] = @region.subnets[manual_network_spec["cloud_properties"]["subnet"]]
        instance_params[:private_ip_address] = manual_network_spec["ip"]
      end
    end

    def set_availability_zone_parameter(volume_zones, resource_pool_zone, subnet_zone)
      availability_zone = @az_selector.common_availability_zone(volume_zones, resource_pool_zone, subnet_zone)
      instance_params[:availability_zone] = availability_zone if availability_zone
    end

    def set_user_data_parameter(networks_spec)
      @instance_params[:user_data] = {registry: {endpoint: @registry.endpoint}}

      spec_with_dns = networks_spec.values.select { |spec| spec.has_key? "dns" }.first
      @instance_params[:user_data][:dns] = {nameserver: spec_with_dns["dns"]} if spec_with_dns
    end

    private

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

  end
end
