# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2013 GoPivotal, Inc.

module Bosh::Agent
  ##
  # BOSH Agent settings for Infrastructure OpenStack
  #
  class Infrastructure::Openstack::Settings

    VIP_NETWORK_TYPE        = 'vip'
    DHCP_NETWORK_TYPE       = 'dynamic'
    MANUAL_NETWORK_TYPE     = 'manual'
    SUPPORTED_NETWORK_TYPES = [VIP_NETWORK_TYPE, DHCP_NETWORK_TYPE, MANUAL_NETWORK_TYPE]

    ##
    # Returns the logger
    #
    # @return [Logger] BOSH Agent logger
    def logger
      Bosh::Agent::Config.logger
    end

    ##
    # Loads the the settings for this agent and set ups the public OpenSSH key
    #
    # @return [Hash] Agent Settings
    def load_settings
      setup_openssh_key
      Infrastructure::Openstack::Registry.get_settings
    end

    ##
    # Gets the network settings for this agent
    #
    # @param [String] network_name Network name
    # @param [Hash] network_properties Network properties
    # @return [Hash] Network info
    # @raise [Bosh::Agent::StateError] if network type is not supported
    def get_network_settings(network_name, network_properties)
      type = network_properties['type'] || 'manual'
      unless SUPPORTED_NETWORK_TYPES.include?(type)
        raise Bosh::Agent::StateError,
              "Unsupported network type '#{type}', valid types are: #{SUPPORTED_NETWORK_TYPES.join(', ')}"
      end

      # Nothing to do for 'vip' and 'manual' networks
      return nil if [VIP_NETWORK_TYPE, MANUAL_NETWORK_TYPE].include? type

      Bosh::Agent::Util.get_network_info
    end

    private

    ##
    # Returns the authorized keys filename for the BOSH user
    #
    # @return [String] authorized keys filename
    def authorized_keys
      File.join(File::SEPARATOR, 'home', BOSH_APP_USER, '.ssh', 'authorized_keys')
    end

    ##
    # Retrieves the public OpenSSH key and stores it at the authorized_keys file
    #
    # @return [void]
    def setup_openssh_key
      public_key = Infrastructure::Openstack::Registry.get_openssh_key
      return if public_key.nil? || public_key.empty?

      FileUtils.mkdir_p(File.dirname(authorized_keys))
      FileUtils.chmod(0700, File.dirname(authorized_keys))
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, File.dirname(authorized_keys))

      File.open(authorized_keys, 'w') { |f| f.write(public_key) }
      FileUtils.chmod(0644, authorized_keys)
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, authorized_keys)
    end
  end
end
