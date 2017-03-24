module Bosh::Registry

  class InstanceManager

    ##
    # Updates instance settings
    # @param [String] instance_id instance id (instance record
    #        will be created in DB if it doesn't already exist)
    # @param [String] settings New settings for the instance
    def update_settings(instance_id, settings)
      params = {
        :instance_id => instance_id
      }

      instance = Models::RegistryInstance[params] || Models::RegistryInstance.new(params)
      instance.settings = settings
      instance.save
    end

    ##
    # Reads instance settings
    # @param [String] instance_id instance id
    # @param [optional, String] remote_ip If this IP is provided,
    #        check will be performed to see if it instance id
    #        actually has this IP address according to the IaaS.
    def read_settings(instance_id, remote_ip = nil)
      check_instance_ips(remote_ip, instance_id) if remote_ip

      get_instance(instance_id).settings
    end

    ##
    # Seletes instance settings
    # @param [String] instance_id instance id
    def delete_settings(instance_id)
      get_instance(instance_id).destroy
    end

    ##
    # Get the list of IPs belonging to this instance
    # @param [String] instance_id instance id
    def instance_ips(instance_id)
      raise NotImplemented, "Default implementation of InstanceManager does not support " \
                            "IPs retrieval. Create IaaS-specific subclass and override this method " \
                            "if IPs verfication is needed."
    end

    private

    def check_instance_ips(ip, instance_id)
      return if ip == "127.0.0.1"
      actual_ips = instance_ips(instance_id)
      unless actual_ips.include?(ip)
        raise InstanceError, "Instance IP mismatch, expected IP is " \
                             "'%s', actual IP(s): '%s'" %
                             [ ip, actual_ips.join(", ") ]
      end
    end

    def get_instance(instance_id)
      instance = Models::RegistryInstance[:instance_id => instance_id]

      if instance.nil?
        raise InstanceNotFound, "Can't find instance '#{instance_id}'"
      end

      instance
    end

  end

end
