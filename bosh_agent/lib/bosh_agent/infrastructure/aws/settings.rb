# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Aws::Settings

    VIP_NETWORK_TYPE = "vip"
    DHCP_NETWORK_TYPE = "dynamic"
    MANUAL_NETWORK_TYPE = "manual"

    SUPPORTED_NETWORK_TYPES = [
      VIP_NETWORK_TYPE, DHCP_NETWORK_TYPE, MANUAL_NETWORK_TYPE
    ]

    AUTHORIZED_KEYS = File.join("/home/", BOSH_APP_USER, ".ssh/authorized_keys")

    def logger
      Bosh::Agent::Config.logger
    end

    def authorized_keys
      AUTHORIZED_KEYS
    end

    def setup_openssh_key
      public_key = Infrastructure::Aws::Registry.get_openssh_key
      if public_key.nil? || public_key.empty?
        return
      end
      FileUtils.mkdir_p(File.dirname(authorized_keys))
      FileUtils.chmod(0700, File.dirname(authorized_keys))
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP,
                      File.dirname(authorized_keys))
      File.open(authorized_keys, "w") { |f| f.write(public_key) }
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP,
                      authorized_keys)
      FileUtils.chmod(0644, authorized_keys)
    end

    def load_settings
      setup_openssh_key
      Infrastructure::Aws::Registry.get_settings
    end

    def get_network_settings(network_name, properties)
      type = properties["type"] || "manual"
      unless type && SUPPORTED_NETWORK_TYPES.include?(type)
        raise Bosh::Agent::StateError,
              "Unsupported network type '%s', valid types are: %s" %
                  [type, SUPPORTED_NETWORK_TYPES.join(', ')]
      end

      # Nothing to do for "vip" and "manual" networks
      return nil if [VIP_NETWORK_TYPE, MANUAL_NETWORK_TYPE].include? type

      Bosh::Agent::Util.get_network_info
    end

  end
end
