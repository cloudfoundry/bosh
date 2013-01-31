module Bosh::AwsCloud
  class AvailabilityZoneSelector
    attr_accessor :region

    def initialize(region, default_name)
      @region = region
      @default = default_name
    end

    def common_availability_zone(volume_az_names, resource_pool_az_name, vpc_subnet_az_name)
      zone_names = (volume_az_names + [resource_pool_az_name, vpc_subnet_az_name]).compact.uniq
      ensure_same_availability_zone(zone_names)

      zone_names.first || @default
    end

    def select_from_instance_id(instance_id)
      if instance_id
        region.instances[instance_id].availability_zone
      else
        @default
      end
    end

    private

    def ensure_same_availability_zone(zone_names)
      raise Bosh::Clouds::CloudError,
            "can't use multiple availability zones: #{zone_names.join(', ')}" if zone_names.size > 1
    end
  end
end