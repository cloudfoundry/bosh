# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Cloudstack::Settings

    VIP_NETWORK_TYPE = "vip"
    DHCP_NETWORK_TYPE = "dynamic"
    MANUAL_NETWORK_TYPE = "manual"

    SUPPORTED_NETWORK_TYPES = [
        VIP_NETWORK_TYPE, DHCP_NETWORK_TYPE
    ]

    ##
    # Returns the logger
    #
    # @return [Logger] Bosh Agent logger
    def logger
      Bosh::Agent::Config.logger
    end

    ##
    # Loads the the settings for this agent and set ups the public OpenSSH key.
    #
    # @return [Hash] Agent Settings
    def load_settings
      setup_openssh_key
      Infrastructure::Cloudstack::Registry.get_settings
    end

    ##
    # Returns the authorized keys filename for the Bosh user.
    #
    # @return [String] authorized keys filename
    def authorized_keys
      File.join(File::SEPARATOR, "home", BOSH_APP_USER, ".ssh", "authorized_keys")
    end

    ##
    # Retrieves the public OpenSSH key and stores it at the authorized_keys file.
    #
    # @return [void]
    def setup_openssh_key
      public_key = Infrastructure::Cloudstack::Registry.get_openssh_key
      return if public_key.nil? || public_key.empty?

      FileUtils.mkdir_p(File.dirname(authorized_keys))
      FileUtils.chmod(0700, File.dirname(authorized_keys))
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, File.dirname(authorized_keys))

      File.open(authorized_keys, "w") { |f| f.write(public_key) }
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, authorized_keys)
      FileUtils.chmod(0644, authorized_keys)
    end

    ##
    # Gets the network settings for this agent.
    #
    # @param [String] network_name Network name
    # @param [Hash] network_properties Network properties
    # @return [Hash] Network settings
    def get_network_settings(network_name, network_properties)
      type = network_properties["type"] || "manual"
      unless type && SUPPORTED_NETWORK_TYPES.include?(type)
        raise Bosh::Agent::StateError, "Unsupported network type '%s', valid types are: %s" %
                                       [type, SUPPORTED_NETWORK_TYPES.join(", ")]
      end

      # Nothing to do for "vip" and "manual" networks
      return nil if [VIP_NETWORK_TYPE, MANUAL_NETWORK_TYPE].include? type

      Bosh::Agent::Util.get_network_info
    end

  end
end
