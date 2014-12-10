# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Registry

  class InstanceManager

    class Aws < InstanceManager

      AWS_MAX_RETRIES = 2

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @aws_properties = cloud_config["aws"]
        @aws_options = {
          :access_key_id => @aws_properties["access_key_id"],
          :secret_access_key => @aws_properties["secret_access_key"],
          :max_retries => @aws_properties["max_retries"] || AWS_MAX_RETRIES,
          :ec2_endpoint => @aws_properties['ec2_endpoint'] || "ec2.#{@aws_properties['region']}.amazonaws.com",
          :logger => @logger
        }
        # configure optional parameters
        %w(
          ssl_verify_peer
          ssl_ca_file
          ssl_ca_path
        ).each do |k|
          @aws_options[k.to_sym] = @aws_properties[k] unless @aws_properties[k].nil?
        end

        @ec2 = AWS::EC2.new(@aws_options)
      end

      def validate_options(cloud_config)
        unless cloud_config.has_key?("aws") &&
            cloud_config["aws"].is_a?(Hash) &&
            cloud_config["aws"]["access_key_id"] &&
            cloud_config["aws"]["secret_access_key"] &&
            cloud_config["aws"]["region"]
          raise ConfigError, "Invalid AWS configuration parameters"
        end
      end

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        instance = @ec2.instances[instance_id]
        ips = [instance.private_ip_address, instance.public_ip_address]
        if instance.has_elastic_ip?
          ips << instance.elastic_ip.public_ip
        end
        ips
      rescue AWS::Errors::Base => e
        raise Bosh::Registry::AwsError, "AWS error: #{e}"
      end

    end

  end

end