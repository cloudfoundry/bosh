# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry

  class InstanceManager

    def initialize
      @logger = Bosh::AwsRegistry.logger
      @ec2 = Bosh::AwsRegistry.ec2
    end

    ##
    # Updates instance settings
    # @param [String] instance_id EC2 instance id (instance record
    #        will be created in DB if it doesn't already exist)
    # @param [String] settings New settings for the instance
    def update_settings(instance_id, settings)
      params = {
        :instance_id => instance_id
      }

      instance = Models::AwsInstance[params] || Models::AwsInstance.new(params)
      instance.settings = settings
      instance.save
    end

    ##
    # Reads instance settings
    # @param [String] instance_id EC2 instance id
    # @param [optional, String] remote_ip If this IP is provided,
    #        check will be performed to see if it instance id
    #        actually has this IP address according to EC2.
    def read_settings(instance_id, remote_ip = nil)
      check_instance_ip(remote_ip, instance_id) if remote_ip

      get_instance(instance_id).settings
    end

    def delete_settings(instance_id)
      get_instance(instance_id).destroy
    end

    private

    def check_instance_ip(ip, instance_id)
      return if ip == "127.0.0.1"
      actual_ip = instance_private_ip(instance_id)
      unless ip == actual_ip
        raise InstanceError, "Instance IP mismatch, expected IP is " \
                             "`%s', actual IP is `%s'" % [ ip, actual_ip ]
      end
    end

    def get_instance(instance_id)
      instance = Models::AwsInstance[:instance_id => instance_id]

      if instance.nil?
        raise InstanceNotFound, "Can't find instance `#{instance_id}'"
      end

      instance
    end

    def instance_private_ip(instance_id)
      @ec2.instances[instance_id].private_ip_address
    rescue AWS::Errors::Base => e
      raise Bosh::AwsRegistry::AwsError, "AWS error: #{e}"
    end

  end

end

