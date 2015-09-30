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
          :max_retries => @aws_properties["max_retries"] || AWS_MAX_RETRIES,
          :ec2_endpoint => @aws_properties['ec2_endpoint'] || "ec2.#{@aws_properties['region']}.amazonaws.com",
          :logger => @logger
        }
        # configure optional parameters
        %w(
          access_key_id
          secret_access_key
          ssl_verify_peer
          ssl_ca_file
          ssl_ca_path
        ).each do |k|
          @aws_options[k.to_sym] = @aws_properties[k] unless @aws_properties[k].nil?
        end

        # credentials_source could be static (default) or env_or_profile
        # static credentials must be included in aws_properties
        # env_or_profile credentials will use the AWS DefaultCredentialsProvider
        # to find AWS credentials in environment variables or EC2 instance profiles

        if cloud_config['aws']['credentials_source'] == 'static' || cloud_config['aws']['credentials_source'].nil?
          @aws_options[:access_key_id] = cloud_config['aws']['access_key_id']
          @aws_options[:secret_access_key] = cloud_config['aws']['secret_access_key']
        end

        @ec2 = AWS::EC2.new(@aws_options)
      end

      def validate_options(cloud_config)
        unless cloud_config.has_key?("aws") &&
            cloud_config["aws"].is_a?(Hash) &&
            cloud_config["aws"]["region"]
          raise ConfigError, "Invalid AWS configuration parameters"
        end

        credentials_source = cloud_config['aws']['credentials_source'] || 'static'

        if credentials_source != 'env_or_profile' && credentials_source != 'static'
          raise ConfigError, "Unknown credentials_source #{credentials_source}"
        end

        if credentials_source == 'static'
          if cloud_config["aws"]["access_key_id"].nil? || cloud_config["aws"]["secret_access_key"].nil?
              raise ConfigError, "Must use access_key_id and secret_access_key with static credentials_source"
          end
        end

        if credentials_source == 'env_or_profile'
          if cloud_config["aws"]["access_key_id"] || cloud_config["aws"]["secret_access_key"]
              raise ConfigError, "Can't use access_key_id and secret_access_key with env_or_profile credentials_source"
          end
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
