# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012-2013 ZJU Software Engineering Laboratory
# Copyright (c) 2013 Nippon Telegraph and Telephone Corporation


module Bosh::Registry

  class InstanceManager

    class Cloudstack < InstanceManager

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @cloudstack_properties = cloud_config["cloudstack"]

        endpoint_uri = URI.parse(@cloudstack_properties["endpoint"])

        @cloudstack_options = {
          :provider => "CloudStack",
          :cloudstack_scheme => endpoint_uri.scheme,
          :cloudstack_host => endpoint_uri.host,
          :cloudstack_port => endpoint_uri.port,
          :cloudstack_path => endpoint_uri.path,
          :cloudstack_api_key => @cloudstack_properties["api_key"],
          :cloudstack_secret_access_key=> @cloudstack_properties["secret_access_key"]
        }
      end

      def cloudstack
        @cloudstack ||= Fog::Compute.new(@cloudstack_options)
      end
      
      def validate_options(cloud_config)
        unless cloud_config.has_key?("cloudstack") &&
            cloud_config["cloudstack"].is_a?(Hash) &&
            cloud_config["cloudstack"]["endpoint"] &&
            cloud_config["cloudstack"]["api_key"] &&
            cloud_config["cloudstack"]["secret_access_key"]
          raise ConfigError, "Invalid CloudStack configuration parameters"
        end
      end

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the CloudStack auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          instance  = cloudstack.servers.find { |s| s.name == instance_id }
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @cloudstack = nil
            retry
          end
          raise ConnectionError, "Unable to connect to CloudStack API: #{e.message}"
        end
        raise InstanceNotFound, "Instance `#{instance_id}' not found" unless instance
        private_ips = instance.nics.map { |nic| nic["ipaddress"] }
        # TODO: Update if Fog gem has been updated 
        floating_ips_response = cloudstack.list_public_ip_addresses["listpublicipaddressesresponse"]
        if floating_ips_response.empty?
          floating_ips = []
        else
          floating_ips = floating_ips_response["publicipaddress"]
            .select { |ip| ip["virtualmachineid"] == instance_id }
            .map { |ip| ip["ipaddress"] }
        end

        return (private_ips + floating_ips).compact
      end

    end

  end

end
