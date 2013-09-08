# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2013 GoPivotal, Inc.

module Bosh::Agent
  ##
  # BOSH Agent registry for Infrastructure OpenStack
  #
  class Infrastructure::Openstack::Registry
    class << self

      attr_accessor :user_data

      HTTP_API_TIMEOUT       = 300
      HTTP_CONNECT_TIMEOUT   = 30
      META_DATA_URI          = 'http://169.254.169.254/latest'
      USER_DATA_FILE         = File.join(File::SEPARATOR, 'var', BOSH_APP_USER, 'bosh', 'user_data.json')
      CONFIG_DRIVE_MOUNT     = File.join(File::SEPARATOR, 'mnt', 'config')
      CONFIG_DRIVE_USER_DATA = File.join(CONFIG_DRIVE_MOUNT, 'openstack', 'latest', 'user_data')
      CONFIG_DRIVE_META_DATA = File.join(CONFIG_DRIVE_MOUNT, 'openstack', 'latest', 'meta_data.json')

      ##
      # Returns the logger
      #
      # @return [Logger] BOSH Agent logger
      def logger
        Bosh::Agent::Config.logger
      end

      ##
      # Gets the OpenSSH public key
      #
      # @return [String] OpenSSH public key
      def get_openssh_key
        openssh_key = get_openssh_key_from_uri
        openssh_key = get_openssh_key_from_file if openssh_key.nil? || openssh_key.empty?
        openssh_key = get_openssh_key_from_config_drive if openssh_key.nil? || openssh_key.empty?

        logger.info('Failed to get OpenSSH public key, skipping') if openssh_key.nil? || openssh_key.empty?
        openssh_key
      end

      ##
      # Gets the settings for this agent from the BOSH Registry
      #
      # @return [Hash] Agent Settings
      # @raise [Bosh::Agent::LoadSettingsError] if can not get settings
      def get_settings
        registry_raw_response = get_uri("#{get_registry_endpoint}/instances/#{get_server_name}/settings")
        registry_data = parse_yajl_data(registry_raw_response)

        unless registry_data.key?('settings')
          raise LoadSettingsError, "Invalid response received from BOSH registry: #{registry_data}"
        end

        settings = parse_yajl_data(registry_data['settings'])

        logger.info("Agent settings: #{settings.inspect}")
        settings
      end

      private

      ##
      # Gets the OpenSSH public key from the OpenStack meta-data service
      #
      # @return [String] OpenSSH public key
      def get_openssh_key_from_uri
        openssh_key = get_uri(META_DATA_URI + '/meta-data/public-keys/0/openssh-key')

        raise LoadSettingsError, 'meta-data does not contain a public key' if openssh_key.nil? || openssh_key.empty?

        openssh_key
      rescue LoadSettingsError => e
        logger.info("Cannot get OpenSSH public key from OpenStack meta-data service: #{e.message}")
        nil
      end

      ##
      # Gets the OpenSSH public key from the OpenStack injected file
      #
      # @return [String] OpenSSH public key
      def get_openssh_key_from_file
        user_data = parse_yajl_data(File.read(USER_DATA_FILE))
        openssh_key = user_data.fetch('openssh', {}).fetch('public_key', nil)

        raise LoadSettingsError, 'user-data does not contain a public key' if openssh_key.nil? || openssh_key.empty?

        openssh_key
      rescue LoadSettingsError, SystemCallError => e
        logger.info("Cannot get OpenSSH public key from OpenStack injected file: #{e.message}")
        nil
      end

      ##
      # Gets the OpenSSH public key from the OpenStack config drive
      #
      # @return [String] OpenSSH public key
      def get_openssh_key_from_config_drive
        mount_config_drive
        meta_data = parse_yajl_data(File.read(CONFIG_DRIVE_META_DATA))
        _, openssh_key = meta_data.fetch('public_keys', {}).shift

        raise LoadSettingsError, 'meta-data does not contain a public key' if openssh_key.nil? || openssh_key.empty?

        openssh_key
      rescue Bosh::Exec::Error, LoadSettingsError, SystemCallError => e
        logger.info("Cannot get OpenSSH public key from OpenStack config drive: #{e.message}")
        nil
      end

      ##
      # Gets the BOSH Registry endpoint
      #
      # @return [String] BOSH Registry endpoint
      # @raise [Bosh::Agent::LoadSettingsError] if can not get the registry endpoint
      def get_registry_endpoint
        user_data = get_user_data
        registry_endpoint = user_data.fetch('registry', {}).fetch('endpoint', nil)

        raise LoadSettingsError, 'Cannot get BOSH registry endpoint from user data' if registry_endpoint.nil?

        lookup_registry_endpoint(user_data)
      end

      ##
      # If the BOSH Registry endpoint is specified with a DNS name, i.e. 0.registry.default.openstack.microbosh,
      # then the agent needs to lookup the name and insert the IP address, as the agent doesn't update
      # resolv.conf until after the bootstrap is run
      #
      # @param [Hash] user_data User data
      # @return [String] BOSH Registry endpoint
      # @raise [Bosh::Agent::LoadSettingsError] if can not look up the registry hostname
      def lookup_registry_endpoint(user_data)
        registry_endpoint = user_data['registry']['endpoint']

        # If user data doesn't contain dns info, there is noting we can do, so just return the endpoint
        nameservers = user_data.fetch('dns', {}).fetch('nameserver', [])
        return registry_endpoint if nameservers.nil? || nameservers.empty?

        # If the endpoint is an IP address, just return the endpoint
        registry_hostname = extract_registry_hostname(registry_endpoint)
        return registry_endpoint if hostname_is_ip_address?(registry_hostname)

        registry_ip = lookup_registry_ip_address(registry_hostname, nameservers)

        inject_registry_ip_address(registry_ip, registry_endpoint)
      rescue Resolv::ResolvError => e
        raise LoadSettingsError, "Cannot lookup #{registry_hostname} using #{nameservers.join(", ")}: #{e.inspect}"
      end

      ##
      # Extracts the hostname from the BOSH Registry endpoint
      #
      # @param [String] endpoint BOSH Registry endpoint
      # @return [String] BOSH Registry hostname
      # @raise [Bosh::Agent::LoadSettingsError] if can not extract the registry endpoint
      def extract_registry_hostname(endpoint)
        match = endpoint.match(%r{https*://([^:]+):})
        unless match && match.size == 2
          raise LoadSettingsError, "Cannot extract Bosh registry hostname from #{endpoint}"
        end

        match[1]
      end

      ##
      # Checks if a hostname is an IP address
      #
      # @param [String] hostname Hostname
      # @return [Boolean] True if hostname is an IP address, false otherwise
      def hostname_is_ip_address?(hostname)
        begin
          IPAddr.new(hostname)
        rescue
          return false
        end
        true
      end

      ##
      # Lookups for the BOSH Registry IP address
      #
      # @param [String] hostname BOSH Registry hostname
      # @param [Array] nameservers Array containing nameserver address
      # @return [Resolv::IPv4] BOSH Registry IP address
      def lookup_registry_ip_address(hostname, nameservers)
        resolver = Resolv::DNS.new(nameserver: nameservers)
        resolver.getaddress(hostname)
      end

      ##
      # Injects an IP address into the BOSH Registry endpoint
      #
      # @param [Resolv::IPv4] ip BOSH Registry IP address
      # @param [String] endpoint BOSH Registry endpoint
      # @return [String] BOSH Registry endpoint
      def inject_registry_ip_address(ip, endpoint)
        endpoint.sub(%r{//[^:]+:}, "//#{ip}:")
      end

      ##
      # Gets the server name
      #
      # @return [String] Server name
      # @raise [Bosh::Agent::LoadSettingsError] if can not get the server name
      def get_server_name
        user_data = get_user_data
        server_name = user_data.fetch('server', {}).fetch('name', nil)

        raise LoadSettingsError, 'Cannot get server name from user data' if server_name.nil?

        server_name
      end

      ##
      # Gets the VM user data
      #
      # @return [Hash] User data
      # @raise [Bosh::Agent::LoadSettingsError] if can not get user data
      def get_user_data
        return @user_data if @user_data

        user_data = get_user_data_from_uri
        user_data = get_user_data_from_file if user_data.nil? || user_data.empty?
        user_data = get_user_data_from_config_drive if user_data.nil? || user_data.empty?

        raise LoadSettingsError, 'Failed to get VM user data' if user_data.nil? || user_data.empty?

        logger.info("OpenStack user data: #{user_data.inspect}")
        @user_data = user_data
      end

      ##
      # Gets the VM user data from the OpenStack meta-data service
      #
      # @return [String] VM user data
      def get_user_data_from_uri
        user_data = parse_yajl_data(get_uri(META_DATA_URI + '/user-data'))

        raise LoadSettingsError, 'user-data is empty' if user_data.nil? || user_data.empty?

        user_data
      rescue LoadSettingsError => e
        logger.info("Cannot get VM user data from OpenStack meta-data service: #{e.message}")
        nil
      end

      ##
      # Gets the VM user data from the OpenStack injected file
      #
      # @return [String] VM user data
      def get_user_data_from_file
        user_data = parse_yajl_data(File.read(USER_DATA_FILE))

        raise LoadSettingsError, 'user-data is empty' if user_data.nil? || user_data.empty?

        user_data
      rescue LoadSettingsError, SystemCallError => e
        logger.info("Cannot get VM user data from OpenStack injected file: #{e.message}")
        nil
      end

      ##
      # Gets the VM user data from the OpenStack config drive
      #
      # @return [String] VM user data
      def get_user_data_from_config_drive
        mount_config_drive
        user_data = parse_yajl_data(File.read(CONFIG_DRIVE_USER_DATA))

        raise LoadSettingsError, 'user-data is empty' if user_data.nil? || user_data.empty?

        user_data
      rescue Bosh::Exec::Error, LoadSettingsError, SystemCallError => e
        logger.info("Cannot get VM user data from OpenStack config drive: #{e.message}")
        nil
      end

      ##
      # Parses a Yajl encoded data
      #
      # @param [String] raw_data Raw data
      # @return [Hash] Json data
      # @raise [Bosh::Agent::LoadSettingsError] if raw date is invalid
      def parse_yajl_data(raw_data)
        begin
          data = Yajl::Parser.parse(raw_data)
        rescue Yajl::ParseError => e
          raise LoadSettingsError, "Cannot parse data: #{e.message}"
        end

        raise LoadSettingsError, "Invalid data: Hash expected, #{data.class} provided" unless data.is_a?(Hash)

        data
      end

      ##
      # Locates the OpenStack config drive and mounts it (if not already mounted)
      #
      # @return [void]
      # @raise [Bosh::Agent::LoadSettingsError] if unable to located the OpenStack config drive
      # @raise [Bosh::Exec:Error] if unable to mount the OpenStack config drive
      def mount_config_drive
        result = Bosh::Exec.sh('blkid -l -t LABEL="config-2" -o device', on_error: :return)
        if result.failed?
          raise LoadSettingsError, "Unable to locate OpenStack config drive device: #{result.exit_status}"
        end

        config_drive_device = result.output.strip
        logger.info("OpenStack config drive located on device '#{config_drive_device}'")
        unless Bosh::Exec.sh("mount | grep #{CONFIG_DRIVE_MOUNT}", on_error: :return).success?
          logger.info("Mounting OpenStack config drive on '#{CONFIG_DRIVE_MOUNT}'")
          Bosh::Exec.sh("mkdir -p #{CONFIG_DRIVE_MOUNT}")
          Bosh::Exec.sh("mount #{config_drive_device} #{CONFIG_DRIVE_MOUNT}")
        end
      end

      ##
      # Sends GET request to an specified URI
      #
      # @param [String] uri URI to request
      # @return [String] Response body
      # @raise [Bosh::Agent::LoadSettingsError] if can not get data from URI
      def get_uri(uri)
        client = HTTPClient.new
        client.send_timeout = HTTP_API_TIMEOUT
        client.receive_timeout = HTTP_API_TIMEOUT
        client.connect_timeout = HTTP_CONNECT_TIMEOUT

        response = client.get(uri, {}, { 'Accept' => 'application/json' })
        raise LoadSettingsError, "Endpoint #{uri} returned HTTP #{response.status}" unless response.status == 200

        response.body
      rescue URI::Error, HTTPClient::TimeoutError, HTTPClient::BadResponseError, SocketError,
          Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, SystemCallError => e
        raise LoadSettingsError, "Error requesting endpoint #{uri}: #{e.inspect}"
      end
    end
  end
end
