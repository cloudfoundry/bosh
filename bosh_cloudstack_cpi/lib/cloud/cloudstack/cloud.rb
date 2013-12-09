# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::CloudStackCloud
  ##
  # BOSH CloudStack CPI
  class Cloud < Bosh::Cloud
    include Helpers

    BOSH_APP_DIR = "/var/vcap/bosh"
    FIRST_DEVICE_NAME_LETTER = "b"
    METADATA_TIMEOUT    = 5 # in seconds
    DEVICE_POLL_TIMEOUT = 60 # in seconds

    attr_reader :compute
    attr_reader :registry
    attr_accessor :logger
    attr_reader :metadata_server
    attr_reader :state_timeout

    ##
    # Creates a new BOSH CloudStack CPI
    #
    # @param [Hash] options CPI options
    # @option options [Hash] cloudstack CloudStack specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = options.dup

      validate_options
      initialize_registry

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options["agent"] || {}
      @fog_properties = @options["cloudstack"]

      @default_key_name = @fog_properties["default_key_name"]
      @default_security_groups = @fog_properties["default_security_groups"] || []
      @state_timeout = @fog_properties["state_timeout"]
      @stemcell_public_visibility = @fog_properties["stemcell_public_visibility"]

      endpoint_uri = URI.parse(@fog_properties["endpoint"])

      fog_params = {
        :provider => 'CloudStack',
        :cloudstack_api_key => @fog_properties["api_key"],
        :cloudstack_secret_access_key => @fog_properties["secret_access_key"],
        :cloudstack_scheme => endpoint_uri.scheme,
        :cloudstack_host => endpoint_uri.host,
        :cloudstack_port => endpoint_uri.port,
        :cloudstack_path => endpoint_uri.path,
      }
      begin
        @compute = Fog::Compute.new(fog_params)
      rescue Exception => e
        @logger.error(e)
        cloud_error("Unable to connect to the CloudStack Compute API. Check task debug log for details.")
      end

      @default_zone = @compute.zones.find { |zone| zone.name == @fog_properties["default_zone"] }
      cloud_error("Unable to find the zone named #{@fog_properties["default_zone"]}.") if @default_zone.nil?
      @metadata_server = @fog_properties["metadata_server"] ||
        %x[grep dhcp-server-identifier /var/lib/dhclient/* /var/lib/dhcp3/* /var/lib/dhcp/* 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d '\;'].strip

      @metadata_lock = Mutex.new
    end

    ##
    # Creates a new CloudStack Image using stemcell image.
    #
    # @param [String] image_path Local filesystem path to a stemcell image
    # @param [Hash] stemcell_properties CPI-specific properties
    # @option stemcell_properties [String] name Stemcell name
    # @option stemcell_properties [String] version Stemcell version
    # @option stemcell_properties [String] infrastructure Stemcell infraestructure
    # @option stemcell_properties [String] disk_format Image disk format
    # @option stemcell_properties [String] container_format Image container format
    # @option stemcell_properties [optional, String] kernel_file Name of the
    #   kernel image file provided at the stemcell archive
    # @option stemcell_properties [optional, String] ramdisk_file Name of the
    #   ramdisk image file provided at the stemcell archive
    # @return [String] CloudStack image UUID of the stemcell
    def create_stemcell(image_path, stemcell_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        creator = StemcellCreator.new(@default_zone, stemcell_properties, self)

        begin
          # These three variables are used in 'ensure' clause
          instance = nil
          volume = nil

          # 1. Create and mount new EBS volume (10GB default)
          disk_size = stemcell_properties["disk"] || (1024 * 10)
          volume_id = create_disk(disk_size, current_vm_id)
          volume = @compute.volumes.get(volume_id)
          instance = @compute.servers.get(current_vm_id)

          device_name = attach_volume(instance, volume)
          device_name = find_volume_device(device_name)

          logger.info("Creating stemcell with: '#{volume.id}' and '#{stemcell_properties.inspect}'")
          image = creator.create(volume, device_name, image_path)

          @compute.zones.reject { |zone| zone.id == @default_zone.id }.each do |zone|
            @logger.debug("Copying Stemcell `#{image.id}' from zone `#{image.zone_name}' (#{image.zone_id}) to zone `#{zone.name}' (#{zone.id})")
            copy_job = image.copy(zone)
            wait_job(copy_job)
          end

          image.id
        rescue => e
          @logger.error(e)
          raise e
        ensure
          if instance && volume
            begin
              detach_volume(instance, volume)
            rescue Bosh::Clouds::CloudError => e
              @logger.info("Volume has been detached already")
            end
            delete_disk(volume.id)
          end
        end
      end
    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell_id CloudStack image UUID of the stemcell to be
    #   deleted
    # @return [void]
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        @logger.info("Deleting stemcell `#{stemcell_id}'...")
        images = with_compute { @compute.images.select { |image| image.id == stemcell_id } }
        images.each do |image|
          with_compute { image.destroy }
          @logger.info("Stemcell `#{stemcell_id}' is now deleted")
        end
      end
    end

    ##
    # Creates an CloudStack server and waits until it's in running state
    #
    # @param [String] agent_id UUID for the agent that will be used later on by
    #   the director to locate and talk to the agent
    # @param [String] stemcell_id CloudStack image UUID that will be used to
    #   power on new server
    # @param [Hash] resource_pool cloud specific properties describing the
    #   resources needed for this VM
    # @param [Hash] networks list of networks and their settings needed for
    #   this VM
    # @param [optional, Array] disk_locality List of disks that might be
    #   attached to this server in the future, can be used as a placement
    #   hint (i.e. server will only be created if resource pool availability
    #   zone is the same as disk availability zone)
    # @param [optional, Hash] environment Data to be merged into agent settings
    # @return [String] CloudStack server UUID
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec = nil, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        @logger.info("Creating new server...")
        server_name = "vm-#{generate_unique_name}"


        image = with_compute { @compute.images.find { |i| i.id == stemcell_id } }
        cloud_error("Image `#{stemcell_id}' not found") if image.nil?
        @logger.debug("Using image: `#{stemcell_id}'")

        flavor = with_compute { @compute.flavors.find { |f| f.name == resource_pool["instance_type"] } }
        cloud_error("Flavor `#{resource_pool["instance_type"]}' not found") if flavor.nil?
        @logger.debug("Using flavor: `#{resource_pool["instance_type"]}'")

        keyname = resource_pool["key_name"] || @default_key_name
        keypair = with_compute do
          # Shoud be updated with @compute.keys
          @compute.key_pairs.find { |k| k.name == keyname }
        end
        cloud_error("Key-pair `#{keyname}' not found") if keypair.nil?
        @logger.debug("Using key-pair: `#{keypair.name}' (#{keypair.fingerprint})")

        # CloudStack::Compute.server.save is broken and does not support sshkey
        server_params = {
          :name => server_name,
          :template_id => image.id,
          :service_offering_id => flavor.id,
          :key_name => keypair.name,
          :user_data => Base64.strict_encode64(Yajl::Encoder.encode(user_data(server_name, network_spec))),
        }

        availability_zone = select_availability_zone(disk_locality, resource_pool["availability_zone"] || @default_zone.name)
        if availability_zone
          selected_zone = compute.zones.find { |zone| zone.name == availability_zone }
          cloud_error("Availability zone `#{availability_zone}' not found") if selected_zone.nil?
          @logger.debug("Using availability zone: `#{selected_zone.name}' (#{selected_zone.id})")
          server_params[:zone_id] = selected_zone.id
        end

        network_configurator = NetworkConfigurator.new(network_spec, selected_zone.network_type.downcase.to_sym)

        compute_security_groups = with_compute { @compute.security_groups }
        requested_security_groups =
          network_configurator.security_groups(@default_security_groups)
        security_groups = []
        compute_security_groups.each do |sg|
          if requested_security_groups.reject! { |request| sg.name == request }
            security_groups << sg
          end
        end
        cloud_error("Security group `#{requested_security_groups.join(', ')}' not found") unless requested_security_groups.empty?

        if selected_zone.security_groups_enabled
          @logger.debug("Using security groups: `#{security_groups.map { |sg| sg.name }.join(', ')}'")
          server_params[:security_groups] = security_groups
        else
          unless security_groups.empty?
            cloud_error("Cannot use security groups `#{security_groups.map { |sg| sg.name }.join(', ')}' becuase security groups are disabled for zone `#{selected_zone.name}'")
          end
          @logger.debug("Security group for zone `#{selected_zone.name}' is disabled")
        end

        ephemeral_volume = resource_pool["ephemeral_volume"] || nil
        if ephemeral_volume
          disk_offering =  @compute.disk_offerings.find { |offer| offer.name == ephemeral_volume }
          cloud_error("Disk offering `#{ephemeral_volume}' not found") if disk_offering.nil?
          @logger.debug("Using offering for ephemeral volume: `#{ephemeral_volume}' (#{disk_offering.id})")
          server_params[:disk_offering_id] = disk_offering.id
        end

        network_name = network_configurator.network_name
        if network_name
          network = @compute.networks.find { |network| network.name == network_name }
          if network
            server_params[:network_ids] = [network.id]
          else
            cloud_error("Network `#{network_name}' not found")
          end
        end

        @logger.debug("Using boot parms: `#{server_params.inspect}'")
        server = with_compute { @compute.servers.create(server_params) }
        @logger.info("Creating new server...")
        begin
          wait_resource(server, :running)
          @logger.info("Server created `#{server.id}'")
        rescue Bosh::Clouds::CloudError => e
          @logger.warn("Failed to create server: #{e.message}")
          raise Bosh::Clouds::VMCreationFailed.new(true)
        end

        @logger.info("Configuring network for server `#{server.id}'...")
        network_configurator.configure(@compute, server)
        @logger.info("Updating settings for server `#{server.id}'...")
        settings = initial_agent_settings(server_name, agent_id, network_spec, environment, ephemeral_volume)
        @registry.update_settings(server.name, settings)
        server.id.to_s
      end
    end

    ##
    # Terminates an CloudStack server and waits until it reports as terminated
    #
    # @param [String] server_id CloudStack server UUID
    # @return [void]
    def delete_vm(server_id)
      with_thread_name("delete_vm(#{server_id})") do
        @logger.info("Deleting server `#{server_id}'...")
        server = with_compute { @compute.servers.get(server_id) }
        if server
          settings = @registry.read_settings(server.name)
          unless settings["disks"]["ephemeral"].nil?
            volume = with_compute do
              @compute.volumes.select { |v| v.server_id == server.id }
                              .find { |v| v.device_id == 1 } # assumes /dev/sdb
            end
            unless volume
              @logger.info("Ephemeral volume has already detached")
            end
          end

          job = with_compute { server.destroy }
          wait_job(job)

          # Delete ephemeral volume
          if volume
            @logger.info("Deleting ephemeral volume `#{volume.id}'...")
            wait_resource(volume, :"", :server_id)
            delete_disk(volume.id)
          end

          @logger.info("Deleting settings for server `#{server.id}'...")
          @registry.delete_settings(server.name)
        else
          @logger.info("Server `#{server_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Checks if an CloudStack server exists
    #
    # @param [String] server_id CloudStack server UUID
    # @return [Boolean] True if the vm exists
    def has_vm?(server_id)
      with_thread_name("has_vm?(#{server_id})") do
        server = with_compute { @compute.servers.get(server_id) }
        !server.nil? && ![:destroyed].include?(server.state.downcase.to_sym)
      end
    end

    ##
    # Reboots an CloudStack Server
    #
    # @param [String] server_id CloudStack server UUID
    # @return [void]
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = with_compute { @compute.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        soft_reboot(server)
      end
    end

    ##
    # Configures networking on existing CloudStack server
    #
    # @param [String] server_id CloudStack server UUID
    # @param [Hash] network_spec Raw network spec passed by director
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If there's a network change that requires the recreation of the VM
    def configure_networks(server_id, network_spec)
      with_thread_name("configure_networks(#{server_id}, ...)") do
        @logger.info("Configuring `#{server_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")
        server = with_compute { @compute.servers.get(server_id) }
        zone = with_compute { @compute.zones.get(server.zone_id) }
        network_configurator = NetworkConfigurator.new(network_spec, zone.network_type.downcase.to_sym)

        cloud_error("Server `#{server_id}' not found") unless server

        compare_security_groups(server, network_configurator.security_groups(@default_security_groups))

        compare_private_ip_addresses(server, network_configurator.private_ip)

        network_configurator.configure(@compute, server)

        update_agent_settings(server) do |settings|
          settings["networks"] = network_spec
        end
      end
    end

    ##
    # Creates a new CloudStack volume
    #
    # @param [Integer] size disk size in MiB
    # @param [optional, String] server_id CloudStack server UUID of the VM that
    #   this disk will be attached to
    # @return [String] CloudStack volume UUID
    def create_disk(size, server_id = nil)
      with_thread_name("create_disk(#{size}, #{server_id})") do
        raise ArgumentError, "Disk size needs to be an integer" unless size.kind_of?(Integer)
        cloud_error("Minimum disk size is 1 GiB") if (size < 1024)
        cloud_error("Maximum disk size is 1 TiB") if (size > 1024 * 1000)

        size_gib = (size / 1024.0).ceil

        # Choose minimum disk offering
        disk_offer = with_compute do
          @compute.disk_offerings.sort_by { |offer| offer.disk_size }
                                 .find { |offer| offer.disk_size >= size_gib }
        end
        cloud_error("No disk offering found for #{size_gib}GB") if disk_offer.nil?

        volume_params = {
          :name => "volume-#{generate_unique_name}",
          :zone_id => @default_zone.id,
          :disk_offering_id => disk_offer.id
        }

        if server_id
          server = with_compute { @compute.servers.get(server_id) }
          if server
            volume_params[:zone_id] = server.zone_id
          end
        end

        @logger.info("Creating new volume...")
        volume = with_compute { @compute.volumes.create(volume_params) }

        @logger.info("Waiting for new volume ready `#{volume.id}'...")
        wait_resource(volume, :allocated)

        volume.id.to_s
      end
    end

    ##
    # Deletes an CloudStack volume
    #
    # @param [String] disk_id CloudStack volume UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")
        volume = with_compute { @compute.volumes.get(disk_id) }
        if volume
          state = volume.state
          if state.to_sym != :Ready
            cloud_error("Cannot delete volume `#{disk_id}', state is #{state}")
          end

          with_compute { volume.destroy }
          # no method to wait for completion
        else
          @logger.info("Volume `#{disk_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Attaches an CloudStack volume to an CloudStack server
    #
    # @param [String] server_id CloudStack server ID
    # @param [String] disk_id CloudStack volume ID
    # @return [void]
    def attach_disk(server_id, disk_id)
      with_thread_name("attach_disk(#{server_id}, #{disk_id})") do
        server = with_compute { @compute.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        volume = with_compute { @compute.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        device_name = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end
      end
    end

    ##
    # Detaches an CloudStack volume from an CloudStack server
    #
    # @param [String] server_id CloudStack server ID
    # @param [String] disk_id CloudStack volume ID
    # @return [void]
    def detach_disk(server_id, disk_id)
      with_thread_name("detach_disk(#{server_id}, #{disk_id})") do
        server = with_compute { @compute.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        volume = with_compute { @compute.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        detach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
        end
      end
    end

    ##
    # Takes a snapshot of an CloudStack volume
    #
    # @param [String] disk_id CloudStack volume UUID
    # @param [Hash] metadata Metadata key/value pairs to add to snapshot
    # @return [String] CloudStack snapshot UUID
    # @raise [Bosh::Clouds::CloudError] if volume is not found
    def snapshot_disk(disk_id, metadata)
      with_thread_name("snapshot_disk(#{disk_id})") do
        volume = compute.volumes.get(disk_id)
        cloud_error("Volume `#{disk_id}' not found") unless volume
        device = volume_device_name(volume.device_id) if volume.device_id

        name = [:deployment, :job, :index].collect { |key| metadata[key] }
        name << device.split('/').last if device

        snapshot = @compute.snapshots.new({:volume_id => volume.id})
        with_compute { snapshot.save(true) }
        wait_resource(snapshot, :backedup)
        logger.info("snapshot '#{snapshot.id}' of volume '#{disk_id}' created")

        [:agent_id, :instance_id, :director_name, :director_uuid].each do |key|
          TagManager.tag(snapshot, key, metadata[key])
        end
        TagManager.tag(snapshot, :device, device) if device
        TagManager.tag(snapshot, 'Name', name.join('/'))

        snapshot.id
      end
    end

    ##
    # Deletes an CloudStack volume snapshot
    #
    # @param [String] snapshot_id CloudStack snapshot UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if snapshot is not in available state
    def delete_snapshot(snapshot_id)
      with_thread_name("delete_snapshot(#{snapshot_id})") do
        @logger.info("Deleting snapshot `#{snapshot_id}'...")
        snapshot = with_compute { @compute.snapshots.get(snapshot_id) }

        if snapshot
          state = snapshot.state
          if state != 'BackedUp'
            cloud_error("Cannot delete snapshot `#{snapshot_id}', state is #{state}")
          end

          job = with_compute { snapshot.destroy }
          wait_job(job)
        else
          @logger.info("Snapshot `#{snapshot_id}' not found. Skipping.")
        end
      end
   end

    ##
    # Set metadata for an CloudStack server
    #
    # @param [String] server_id CloudStack server UUID
    # @param [Hash] metadata Metadata key/value pairs
    # @return [void]
    def set_vm_metadata(server_id, metadata)
      with_thread_name("set_vm_metadata(#{server_id}, ...)") do
        with_compute do
          server = @compute.servers.get(server_id)
          cloud_error("Server `#{server_id}' not found") unless server

          metadata.each do |name, value|
            TagManager.tag(server, name, value)
          end
        end
      end
    end

    ##
    # Validates the deployment
    #
    # @note Not implemented in the CloudStack CPI
    def validate_deployment(old_manifest, new_manifest)
      not_implemented(:validate_deployment)
    end

    ##
    # Selects the availability zone to use from a list of disk volumes,
    # resource pool availability zone (if any) and the default availability
    # zone.
    #
    # @param [Array] volumes CloudStack volume UUIDs to attach to the vm
    # @param [String] resource_pool_az availability zone specified in
    #   the resource pool (may be nil)
    # @return [String] availability zone to use or nil
    # @note this is a private method that is public to make it easier to test
    def select_availability_zone(volumes, resource_pool_az)
      if volumes && !volumes.empty?
        disks = volumes.map { |vid| with_compute { @compute.volumes.get(vid) } }
        ensure_same_availability_zone(disks, resource_pool_az)
        disks.first.availability_zone
      else
        resource_pool_az
      end
    end

    ##
    # Ensure all supplied availability zones are the same
    #
    # @param [Array] disks CloudStack volumes
    # @param [String] default availability zone specified in
    #   the resource pool (may be nil)
    # @return [String] availability zone to use or nil
    # @note this is a private method that is public to make it easier to test
    def ensure_same_availability_zone(disks, default)
      zones = disks.map { |disk| disk.availability_zone }
      zones << default if default
      zones.uniq!
      cloud_error "can't use multiple availability zones: %s" %
        zones.join(", ") unless zones.size == 1 || zones.empty?
    end

    ##
    # Detaches an CloudStack volume from an CloudStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @param [Fog::Compute::CloudStack::Volume] volume CloudStack volume
    # @return [void]
    def detach_volume(server, volume)
      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}'...")
      volume.reload

      unless volume.server_id.nil?
        with_compute do
          job = volume.detach
          wait_job(job)
        end
      else
        @logger.info("Disk `#{volume.id}' is not attached to server `#{server.id}'. Skipping.")
      end
    end

    def find_volume_device(sd_name)
      # need also xvd?
      vd_name = sd_name.gsub(/^\/dev\/sd/, "/dev/vd")

      DEVICE_POLL_TIMEOUT.times do
        if File.blockdev?(sd_name)
          return sd_name
        elsif File.blockdev?(vd_name)
          return vd_name
        end
        sleep(1)
      end

      cloud_error("Cannot find volume on current instance")
    end

    private

    ##
    # Generates an unique name
    #
    # @return [String] Unique name
    def generate_unique_name
      SecureRandom.uuid
    end

    ##
    # Prepare server user data
    #
    # @param [String] server_name server name
    # @param [Hash] network_spec network specification
    # @return [Hash] server user data
    def user_data(server_name, network_spec, public_key = nil)
      data = {}

      data["registry"] = { "endpoint" => @registry.endpoint }
      data["server"] = { "name" => server_name }
      data["openssh"] = { "public_key" => public_key } if public_key

      with_dns(network_spec) do |servers|
        data["dns"] = { "nameserver" => servers }
      end

      data
    end

    ##
    # Extract dns server list from network spec and yield the the list
    #
    # @param [Hash] network_spec network specification for instance
    # @yield [Array]
    def with_dns(network_spec)
      network_spec.each_value do |properties|
        if properties.has_key?("dns") && !properties["dns"].nil?
          yield properties["dns"]
          return
        end
      end
    end

    ##
    # Generates initial agent settings. These settings will be read by Bosh Agent from Bosh Registry on a target 
    # server. Disk conventions in Bosh Agent for CloudStack are:
    # - system disk: /dev/sda
    # - ephemeral disk: /dev/sdb or nil
    # - persistent disks: /dev/sdb through /dev/sdc
    # As some kernels remap device names (from sd* to vd* or xvd*), Bosh Agent will lookup for the proper device name 
    #
    # @param [String] server_name Name of the CloudStack server (will be picked
    #   up by agent to fetch registry settings)
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment Environment settings
    # @return [Hash] Agent settings
    def initial_agent_settings(server_name, agent_id, network_spec, environment, ephemeral_volume)
      settings = {
        "vm" => {
          "name" => server_name
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
        "disks" => {
          "system" => "/dev/sda",
          "persistent" => {},
          "ephemeral" => ephemeral_volume.nil? ? nil: "/dev/sdb",
        }
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    ##
    # Updates the agent settings
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    def update_agent_settings(server)
      raise ArgumentError, "Block is not provided" unless block_given?

      @logger.info("Updating settings for server `#{server.id}'...")
      settings = @registry.read_settings(server.name)
      yield settings
      @registry.update_settings(server.name, settings)
    end

    ##
    # Soft reboots an CloudStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @return [void]
    def soft_reboot(server)
      @logger.info("Soft rebooting server `#{server.id}'...")
      wait_job(with_compute { server.reboot })
    end

    ##
    # Hard reboots an CloudStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @return [void]
    def hard_reboot(server)
      @logger.info("Hard rebooting server `#{server.id}'...")
      job = with_compute { server.stop({:force => true}) }
      wait_job(job)
      job = with_compute { server.start }
      wait_job(job)
    end

    ##
    # Attaches an CloudStack volume to an CloudStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @param [Fog::Compute::CloudStack::Volume] volume CloudStack volume
    # @return [String] Device name
    def attach_volume(server, volume)
      @logger.info("Attaching volume `#{volume.id}' to server `#{server.id}'...")
      attached_volume = with_compute do
        @compute.volumes.find { |candidate| candidate.id == volume.id && candidate.server_id == server.id }
      end

      device_id = nil
      if attached_volume.nil?
        @logger.info("Attaching volume `#{volume.id}' to server `#{server.id}'")
        with_compute do
          job = volume.attach(server)
          wait_job(job)
          device_id = job.job_result["volume"]["deviceid"].to_i
        end
      else
        @logger.info("Volume `#{volume.id}' is already attached to server `#{server.id}'. Skipping.")
        device_id = attached_volume.device_id.to_i
      end

      if device_id > 3
        # device_id 3 is skipped by CloudStack
        # https://github.com/apache/cloudstack/blob/4.2/server/src/com/cloud/storage/VolumeManagerImpl.java#L2671
        aligned_device_id = device_id - 1
      else
        aligned_device_id = device_id
      end

      device_name = volume_device_name(aligned_device_id)
      @logger.info("Volume `#{volume.id}' attached to server `#{server.id}' with device_id `#{device_id}' and device name `#{device_name}'")
      device_name
    end

    ##
    # Compares actual server security groups with those specified at the network spec
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @param [Array] specified_sg_names Security groups specified at the network spec
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If the security groups change, we need to recreate the VM as you can't 
    # change the security group of a running server, so we need to send the InstanceUpdater a request to do it for us
    def compare_security_groups(server, specified_sg_names)
      actual_sg_names = with_compute { server.security_groups }.collect { |sg| sg.name }

      unless actual_sg_names.sort == specified_sg_names.sort
        raise Bosh::Clouds::NotSupported,
              "security groups change requires VM recreation: %s to %s" %
              [actual_sg_names.join(", "), specified_sg_names.join(", ")]
      end
    end

    ##
    # Compares actual server private IP addresses with the IP address specified at the network spec
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @param [String] specified_ip_address IP address specified at the network spec (if Manual network)
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If the IP address change, we need to recreate the VM as you can't 
    # change the IP address of a running server, so we need to send the InstanceUpdater a request to do it for us
    def compare_private_ip_addresses(server, specified_ip_address)
      actual_ip_addresses = with_compute { server.addresses }.map { |address| address.ip_address}

      unless specified_ip_address.nil? || actual_ip_addresses.include?(specified_ip_address)
        raise Bosh::Clouds::NotSupported,
              "IP address change requires VM recreation: %s to %s" %
              [actual_ip_addresses.join(", "), specified_ip_address]
      end
    end


    ##
    # Unpacks a stemcell archive
    #
    # @param [String] tmp_dir Temporary directory
    # @param [String] image_path Local filesystem path to a stemcell image
    # @return [void]
    def unpack_image(tmp_dir, image_path)
      result = Bosh::Exec.sh("tar -C #{tmp_dir} -xzf #{image_path} 2>&1", :on_error => :return)
      if result.failed?
        @logger.error("Extracting stemcell root image failed in dir #{tmp_dir}, " +
                      "tar returned #{result.exit_status}, output: #{result.output}")
        cloud_error("Extracting stemcell root image failed. Check task debug log for details.")
      end
      root_image = File.join(tmp_dir, "root.img")
      unless File.exists?(root_image)
        cloud_error("Root image is missing from stemcell archive")
      end
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    # @return [void]
    # @raise [ArgumentError] if options are not valid
    def validate_options
      unless @options["cloudstack"].is_a?(Hash) &&
          @options.has_key?("cloudstack") &&
          @options["cloudstack"]["api_key"] &&
          @options["cloudstack"]["secret_access_key"] &&
          @options["cloudstack"]["endpoint"]

        raise ArgumentError, "Invalid CloudStack configuration parameters"
      end

      unless @options.has_key?("registry") &&
          @options["registry"].is_a?(Hash) &&
          @options["registry"]["endpoint"] &&
          @options["registry"]["user"] &&
          @options["registry"]["password"]
        raise ArgumentError, "Invalid registry configuration parameters"
      end
    end

    def initialize_registry
      registry_properties = @options.fetch('registry')
      registry_endpoint   = registry_properties.fetch('endpoint')
      registry_user       = registry_properties.fetch('user')
      registry_password   = registry_properties.fetch('password')

      @registry = Bosh::Registry::Client.new(registry_endpoint,
                                             registry_user,
                                             registry_password)
    end

    ##
    # Reads current instance id from CloudStack metadata. We are assuming
    # instance id cannot change while current process is running
    # and thus memoizing it.
    def current_vm_id
      @metadata_lock.synchronize do
        return @current_vm_id if @current_vm_id

        client = HTTPClient.new
        client.connect_timeout = METADATA_TIMEOUT
        uri = "http://#{metadata_server}/latest/instance-id"

        response = client.get(uri)
        unless response.status == 200
          cloud_error("Instance metadata endpoint returned " \
                      "HTTP #{response.status}")
        end

        @current_vm_id = response.body
      end

    rescue HTTPClient::TimeoutError
      cloud_error("Timed out reading instance metadata, " \
                  "please make sure CPI is running on EC2 instance")
    end

    def volume_device_name(device_id)
      # assumes device name begins with "dev/sd" and volume_name is numeric
      cloud_error("Unkown device id given") if device_id.nil?
      suffix = ('a'..'z').to_a[device_id]
      cloud_error("too many disks attached") if suffix.nil?
      "/dev/sd#{suffix}"
    end

  end
end
