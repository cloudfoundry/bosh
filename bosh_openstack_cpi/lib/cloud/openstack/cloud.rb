# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  # BOSH OpenStack CPI
  class Cloud < Bosh::Cloud
    include Helpers

    OPTION_KEYS = ['openstack', 'registry', 'agent']

    BOSH_APP_DIR = '/var/vcap/bosh'
    FIRST_DEVICE_NAME_LETTER = 'b'

    attr_reader :openstack
    attr_reader :registry
    attr_reader :glance
    attr_reader :volume
    attr_reader :state_timeout
    attr_accessor :logger

    ##
    # Creates a new BOSH OpenStack CPI
    #
    # @param [Hash] options CPI options
    # @option options [Hash] openstack OpenStack specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = normalize_options(options)

      validate_options
      initialize_registry

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options['agent'] || {}
      @openstack_properties = @options['openstack']

      @default_key_name = @openstack_properties["default_key_name"]
      @default_security_groups = @openstack_properties["default_security_groups"]
      @state_timeout = @openstack_properties["state_timeout"]
      @stemcell_public_visibility = @openstack_properties["stemcell_public_visibility"]
      @wait_resource_poll_interval = @openstack_properties["wait_resource_poll_interval"]
      @boot_from_volume = @openstack_properties["boot_from_volume"]
      @boot_volume_cloud_properties = @openstack_properties["boot_volume_cloud_properties"] || {}

      unless @openstack_properties['auth_url'].match(/\/tokens$/)
        @openstack_properties['auth_url'] = @openstack_properties['auth_url'] + '/tokens'
      end

      @openstack_properties['connection_options'] ||= {}

      extra_connection_options = {'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor}

      openstack_params = {
        :provider => 'OpenStack',
        :openstack_auth_url => @openstack_properties['auth_url'],
        :openstack_username => @openstack_properties['username'],
        :openstack_api_key => @openstack_properties['api_key'],
        :openstack_tenant => @openstack_properties['tenant'],
        :openstack_region => @openstack_properties['region'],
        :openstack_endpoint_type => @openstack_properties['endpoint_type'],
        :connection_options => @openstack_properties['connection_options'].merge(extra_connection_options)
      }
      begin
        @openstack = Fog::Compute.new(openstack_params)
      rescue Exception => e
        @logger.error(e)
        cloud_error('Unable to connect to the OpenStack Compute API. Check task debug log for details.')
      end

      @az_provider = Bosh::OpenStackCloud::AvailabilityZoneProvider.new(
        @openstack,
        @openstack_properties["ignore_server_availability_zone"])

      glance_params = {
        :provider => 'OpenStack',
        :openstack_auth_url => @openstack_properties['auth_url'],
        :openstack_username => @openstack_properties['username'],
        :openstack_api_key => @openstack_properties['api_key'],
        :openstack_tenant => @openstack_properties['tenant'],
        :openstack_region => @openstack_properties['region'],
        :openstack_endpoint_type => @openstack_properties['endpoint_type'],
        :connection_options => @openstack_properties['connection_options'].merge(extra_connection_options)
      }
      begin
        @glance = Fog::Image.new(glance_params)
      rescue Exception => e
        @logger.error(e)
        cloud_error('Unable to connect to the OpenStack Image Service API. Check task debug log for details.')
      end

      volume_params = {
        :provider => "OpenStack",
        :openstack_auth_url => @openstack_properties['auth_url'],
        :openstack_username => @openstack_properties['username'],
        :openstack_api_key => @openstack_properties['api_key'],
        :openstack_tenant => @openstack_properties['tenant'],
        :openstack_region => @openstack_properties['region'],
        :openstack_endpoint_type => @openstack_properties['endpoint_type'],
        :connection_options => @openstack_properties['connection_options'].merge(extra_connection_options)
      }
      begin
        @volume = Fog::Volume.new(volume_params)
      rescue Exception => e
        @logger.error(e)
        cloud_error("Unable to connect to the OpenStack Volume API. Check task debug log for details.")
      end

      @metadata_lock = Mutex.new
    end

    ##
    # Creates a new OpenStack Image using stemcell image. It requires access
    # to the OpenStack Glance service.
    #
    # @param [String] image_path Local filesystem path to a stemcell image
    # @param [Hash] cloud_properties CPI-specific properties
    # @option cloud_properties [String] name Stemcell name
    # @option cloud_properties [String] version Stemcell version
    # @option cloud_properties [String] infrastructure Stemcell infraestructure
    # @option cloud_properties [String] disk_format Image disk format
    # @option cloud_properties [String] container_format Image container format
    # @option cloud_properties [optional, String] kernel_file Name of the
    #   kernel image file provided at the stemcell archive
    # @option cloud_properties [optional, String] ramdisk_file Name of the
    #   ramdisk image file provided at the stemcell archive
    # @return [String] OpenStack image UUID of the stemcell
    def create_stemcell(image_path, cloud_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
          Dir.mktmpdir do |tmp_dir|
            @logger.info('Creating new image...')
            image_params = {
              :name => "BOSH-#{generate_unique_name}",
              :disk_format => cloud_properties['disk_format'],
              :container_format => cloud_properties['container_format'],
              :is_public => @stemcell_public_visibility.nil? ? false : @stemcell_public_visibility,
            }

            image_properties = {}
            vanilla_options = ['name', 'version', 'os_type', 'os_distro', 'architecture', 'auto_disk_config',
                               'hw_vif_model', 'hypervisor_type', 'vmware_adaptertype', 'vmware_disktype',
                               'vmware_linked_clone', 'vmware_ostype']
            vanilla_options.reject{ |o| cloud_properties[o].nil? }.each do |key|
              image_properties[key.to_sym] = cloud_properties[key]
            end
            image_params[:properties] = image_properties unless image_properties.empty?

            # If image_location is set in cloud properties, then pass the copy-from parm. Then Glance will fetch it
            # from the remote location on a background job and store it in its repository.
            # Otherwise, unpack image to temp directory and upload to Glance the root image.
            if cloud_properties['image_location']
              @logger.info("Using remote image from `#{cloud_properties['image_location']}'...")
              image_params[:copy_from] = cloud_properties['image_location']
            else
              @logger.info("Extracting stemcell file to `#{tmp_dir}'...")
              unpack_image(tmp_dir, image_path)
              image_params[:location] = File.join(tmp_dir, 'root.img')
            end

            # Upload image using Glance service
            @logger.debug("Using image parms: `#{image_params.inspect}'")
            image = with_openstack { @glance.images.create(image_params) }

            @logger.info("Creating new image `#{image.id}'...")
            wait_resource(image, :active)

            image.id.to_s
          end
        rescue => e
          @logger.error(e)
          raise e
        end
      end
    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell_id OpenStack image UUID of the stemcell to be
    #   deleted
    # @return [void]
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        @logger.info("Deleting stemcell `#{stemcell_id}'...")
        image = with_openstack { @glance.images.find_by_id(stemcell_id) }
        if image
          with_openstack { image.destroy }
          @logger.info("Stemcell `#{stemcell_id}' is now deleted")
        else
          @logger.info("Stemcell `#{stemcell_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Creates an OpenStack server and waits until it's in running state
    #
    # @param [String] agent_id UUID for the agent that will be used later on by
    #   the director to locate and talk to the agent
    # @param [String] stemcell_id OpenStack image UUID that will be used to
    #   power on new server
    # @param [Hash] resource_pool cloud specific properties describing the
    #   resources needed for this VM
    # @param [Hash] network_spec list of networks and their settings needed for
    #   this VM
    # @param [optional, Array] disk_locality List of disks that might be
    #   attached to this server in the future, can be used as a placement
    #   hint (i.e. server will only be created if resource pool availability
    #   zone is the same as disk availability zone)
    # @param [optional, Hash] environment Data to be merged into agent settings
    # @return [String] OpenStack server UUID
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec = nil, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        @logger.info('Creating new server...')
        server_name = "vm-#{generate_unique_name}"

        network_configurator = NetworkConfigurator.new(network_spec)

        openstack_security_groups = with_openstack { @openstack.security_groups }.collect { |sg| sg.name }
        security_groups = network_configurator.security_groups(@default_security_groups)
        security_groups.each do |sg|
          cloud_error("Security group `#{sg}' not found") unless openstack_security_groups.include?(sg)
        end
        @logger.debug("Using security groups: `#{security_groups.join(', ')}'")

        nics = network_configurator.nics
        @logger.debug("Using NICs: `#{nics.join(', ')}'")

        image = with_openstack { @openstack.images.find { |i| i.id == stemcell_id } }
        cloud_error("Image `#{stemcell_id}' not found") if image.nil?
        @logger.debug("Using image: `#{stemcell_id}'")

        flavor = with_openstack { @openstack.flavors.find { |f| f.name == resource_pool['instance_type'] } }
        cloud_error("Flavor `#{resource_pool['instance_type']}' not found") if flavor.nil?
        if flavor_has_ephemeral_disk?(flavor)
          if flavor.ram
            # Ephemeral disk size should be at least the double of the vm total memory size, as agent will need:
            # - vm total memory size for swapon,
            # - the rest for /var/vcap/data
            min_ephemeral_size = (flavor.ram / 1024) * 2
            if flavor.ephemeral < min_ephemeral_size
              cloud_error("Flavor `#{resource_pool['instance_type']}' should have at least #{min_ephemeral_size}Gb " +
                'of ephemeral disk')
            end
          end
        end
        @logger.debug("Using flavor: `#{resource_pool['instance_type']}'")

        keyname = resource_pool['key_name'] || @default_key_name
        keypair = with_openstack { @openstack.key_pairs.find { |k| k.name == keyname } }
        cloud_error("Key-pair `#{keyname}' not found") if keypair.nil?
        @logger.debug("Using key-pair: `#{keypair.name}' (#{keypair.fingerprint})")

        use_config_drive = !!@openstack_properties.fetch("config_drive", nil)

        if resource_pool['scheduler_hints']
          @logger.debug("Using scheduler hints: `#{resource_pool['scheduler_hints']}'")
        end

        server_params = {
          :name => server_name,
          :image_ref => image.id,
          :flavor_ref => flavor.id,
          :key_name => keypair.name,
          :security_groups => security_groups,
          :os_scheduler_hints => resource_pool['scheduler_hints'],
          :nics => nics,
          :config_drive => use_config_drive,
          :user_data => Yajl::Encoder.encode(user_data(server_name, network_spec))
        }

        availability_zone = @az_provider.select(disk_locality, resource_pool['availability_zone'])
        server_params[:availability_zone] = availability_zone if availability_zone

        if @boot_from_volume
          boot_vol_size = flavor.disk * 1024

          boot_vol_id = create_boot_disk(boot_vol_size, stemcell_id, availability_zone, @boot_volume_cloud_properties)
          cloud_error("Failed to create boot volume.") if boot_vol_id.nil?
          @logger.debug("Using boot volume: `#{boot_vol_id}'")

          server_params[:block_device_mapping] = [{
                                                   :volume_size => "",
                                                   :volume_id => boot_vol_id,
                                                   :delete_on_termination => "1",
                                                   :device_name => "/dev/vda"
                                                 }]
        end

        @logger.debug("Using boot parms: `#{server_params.inspect}'")
        server = with_openstack { @openstack.servers.create(server_params) }

        @logger.info("Creating new server `#{server.id}'...")
        begin
          wait_resource(server, :active, :state)
        rescue Bosh::Clouds::CloudError => e
          @logger.warn("Failed to create server: #{e.message}")

          with_openstack { server.destroy }

          raise Bosh::Clouds::VMCreationFailed.new(true)
        end

        @logger.info("Configuring network for server `#{server.id}'...")
        network_configurator.configure(@openstack, server)

        @logger.info("Updating settings for server `#{server.id}'...")
        settings = initial_agent_settings(server_name, agent_id, network_spec, environment,
                                          flavor_has_ephemeral_disk?(flavor))
        @registry.update_settings(server.name, settings)

        server.id.to_s
      end
    end

    ##
    # Terminates an OpenStack server and waits until it reports as terminated
    #
    # @param [String] server_id OpenStack server UUID
    # @return [void]
    def delete_vm(server_id)
      with_thread_name("delete_vm(#{server_id})") do
        @logger.info("Deleting server `#{server_id}'...")
        server = with_openstack { @openstack.servers.get(server_id) }
        if server
          with_openstack { server.destroy }
          wait_resource(server, [:terminated, :deleted], :state, true)

          @logger.info("Deleting settings for server `#{server.id}'...")
          @registry.delete_settings(server.name)
        else
          @logger.info("Server `#{server_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Checks if an OpenStack server exists
    #
    # @param [String] server_id OpenStack server UUID
    # @return [Boolean] True if the vm exists
    def has_vm?(server_id)
      with_thread_name("has_vm?(#{server_id})") do
        server = with_openstack { @openstack.servers.get(server_id) }
        !server.nil? && ![:terminated, :deleted].include?(server.state.downcase.to_sym)
      end
    end

    ##
    # Reboots an OpenStack Server
    #
    # @param [String] server_id OpenStack server UUID
    # @return [void]
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = with_openstack { @openstack.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        soft_reboot(server)
      end
    end

    ##
    # Configures networking on existing OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [Hash] network_spec Raw network spec passed by director
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If there's a network change that requires the recreation of the VM
    def configure_networks(server_id, network_spec)
      with_thread_name("configure_networks(#{server_id}, ...)") do
        @logger.info("Configuring `#{server_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")
        network_configurator = NetworkConfigurator.new(network_spec)

        server = with_openstack { @openstack.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        compare_security_groups(server, network_configurator.security_groups(@default_security_groups))

        compare_private_ip_addresses(server, network_configurator.private_ips)

        network_configurator.configure(@openstack, server)

        update_agent_settings(server) do |settings|
          settings['networks'] = network_spec
        end
      end
    end

    ##
    # Creates a new OpenStack volume
    #
    # @param [Integer] size disk size in MiB
    # @param [optional, String] server_id OpenStack server UUID of the VM that
    #   this disk will be attached to
    # @return [String] OpenStack volume UUID
    def create_disk(size, cloud_properties, server_id = nil)
      with_thread_name("create_disk(#{size}, #{cloud_properties}, #{server_id})") do
        raise ArgumentError, 'Disk size needs to be an integer' unless size.kind_of?(Integer)
        cloud_error('Minimum disk size is 1 GiB') if (size < 1024)

        volume_params = {
          :display_name => "volume-#{generate_unique_name}",
          :display_description => '',
          :size => (size / 1024.0).ceil
        }

        if cloud_properties.has_key?('type')
          volume_params[:volume_type] = cloud_properties['type']
        end

        if server_id  && @az_provider.constrain_to_server_availability_zone?
          server = with_openstack { @openstack.servers.get(server_id) }
          if server && server.availability_zone
            volume_params[:availability_zone] = server.availability_zone
          end
        end

        @logger.info('Creating new volume...')
        new_volume = with_openstack { @volume.volumes.create(volume_params) }

        @logger.info("Creating new volume `#{new_volume.id}'...")
        wait_resource(new_volume, :available)

        new_volume.id.to_s
      end
    end

    ##
    # Creates a new OpenStack boot volume
    #
    # @param [Integer] size disk size in MiB
    # @param [String] stemcell_id OpenStack image UUID that will be used to
    #   populate the boot volume
    # @param [optional, String] availability_zone to be passed to the volume API
    # @param [optional, String] volume_type to be passed to the volume API
    # @return [String] OpenStack volume UUID
    def create_boot_disk(size, stemcell_id, availability_zone = nil, boot_volume_cloud_properties = {})
      with_thread_name("create_boot_disk(#{size}, #{stemcell_id}, #{availability_zone}, #{boot_volume_cloud_properties})") do
        raise ArgumentError, "Disk size needs to be an integer" unless size.kind_of?(Integer)
        cloud_error("Minimum disk size is 1 GiB") if (size < 1024)

        volume_params = {
          :display_name => "volume-#{generate_unique_name}",
          :size => (size / 1024.0).ceil,
          :imageRef => stemcell_id
        }

        if availability_zone && @az_provider.constrain_to_server_availability_zone?
          volume_params[:availability_zone] = availability_zone
        end
        volume_params[:volume_type] = boot_volume_cloud_properties["type"] if boot_volume_cloud_properties["type"]

        @logger.info("Creating new boot volume...")
        boot_volume = with_openstack { @volume.volumes.create(volume_params) }

        @logger.info("Creating new boot volume `#{boot_volume.id}'...")
        wait_resource(boot_volume, :available)

        boot_volume.id.to_s
      end
    end

    ##
    # Deletes an OpenStack volume
    #
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")
        volume = with_openstack { @openstack.volumes.get(disk_id) }
        if volume
          state = volume.status
          if state.to_sym != :available
            cloud_error("Cannot delete volume `#{disk_id}', state is #{state}")
          end

          with_openstack { volume.destroy }
          wait_resource(volume, :deleted, :status, true)
        else
          @logger.info("Volume `#{disk_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    def attach_disk(server_id, disk_id)
      with_thread_name("attach_disk(#{server_id}, #{disk_id})") do
        server = with_openstack { @openstack.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        volume = with_openstack { @openstack.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        device_name = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings['disks'] ||= {}
          settings['disks']['persistent'] ||= {}
          settings['disks']['persistent'][disk_id] = device_name
        end
      end
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    def detach_disk(server_id, disk_id)
      with_thread_name("detach_disk(#{server_id}, #{disk_id})") do
        server = with_openstack { @openstack.servers.get(server_id) }
        cloud_error("Server `#{server_id}' not found") unless server

        volume = with_openstack { @openstack.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        detach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings['disks'] ||= {}
          settings['disks']['persistent'] ||= {}
          settings['disks']['persistent'].delete(disk_id)
        end
      end
    end

    ##
    # Takes a snapshot of an OpenStack volume
    #
    # @param [String] disk_id OpenStack volume UUID
    # @param [Hash] metadata Metadata key/value pairs to add to snapshot
    # @return [String] OpenStack snapshot UUID
    # @raise [Bosh::Clouds::CloudError] if volume is not found
    def snapshot_disk(disk_id, metadata)
      with_thread_name("snapshot_disk(#{disk_id})") do
        volume = with_openstack { @openstack.volumes.get(disk_id) }
        cloud_error("Volume `#{disk_id}' not found") unless volume

        devices = []
        volume.attachments.each { |attachment| devices << attachment['device'] unless attachment.empty? }

        description = [:deployment, :job, :index].collect { |key| metadata[key] }
        description << devices.first.split('/').last unless devices.empty?
        snapshot_params = {
          :name => "snapshot-#{generate_unique_name}",
          :description => description.join('/'),
          :volume_id => volume.id
        }

        @logger.info("Creating new snapshot for volume `#{disk_id}'...")
        snapshot = @openstack.snapshots.new(snapshot_params)
        with_openstack { snapshot.save(true) }

        @logger.info("Creating new snapshot `#{snapshot.id}' for volume `#{disk_id}'...")
        wait_resource(snapshot, :available)

        snapshot.id.to_s
      end
    end

    ##
    # Deletes an OpenStack volume snapshot
    #
    # @param [String] snapshot_id OpenStack snapshot UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if snapshot is not in available state
    def delete_snapshot(snapshot_id)
      with_thread_name("delete_snapshot(#{snapshot_id})") do
        @logger.info("Deleting snapshot `#{snapshot_id}'...")
        snapshot = with_openstack { @openstack.snapshots.get(snapshot_id) }
        if snapshot
          state = snapshot.status
          if state.to_sym != :available
            cloud_error("Cannot delete snapshot `#{snapshot_id}', state is #{state}")
          end

          with_openstack { snapshot.destroy }
          wait_resource(snapshot, :deleted, :status, true)
        else
          @logger.info("Snapshot `#{snapshot_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Set metadata for an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [Hash] metadata Metadata key/value pairs
    # @return [void]
    def set_vm_metadata(server_id, metadata)
      with_thread_name("set_vm_metadata(#{server_id}, ...)") do
        with_openstack do
          server = @openstack.servers.get(server_id)
          cloud_error("Server `#{server_id}' not found") unless server

          metadata.each do |name, value|
            TagManager.tag(server, name, value)
          end
        end
      end
    end

    ##
    # Selects the availability zone to use from a list of disk volumes,
    # resource pool availability zone (if any) and the default availability
    # zone.
    #
    # @param [Array] volumes OpenStack volume UUIDs to attach to the vm
    # @param [String] resource_pool_az availability zone specified in
    #   the resource pool (may be nil)
    # @return [String] availability zone to use or nil
    # @note this is a private method that is public to make it easier to test
    def select_availability_zone(volumes, resource_pool_az)
      @az_provider.select(volumes, resource_pool_az)
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

      data['registry'] = { 'endpoint' => @registry.endpoint }
      data['server'] = { 'name' => server_name }
      data['openssh'] = { 'public_key' => public_key } if public_key
      data['networks'] = network_spec

      with_dns(network_spec) do |servers|
        data['dns'] = { 'nameserver' => servers }
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
        if properties.has_key?('dns') && !properties['dns'].nil?
          yield properties['dns']
          return
        end
      end
    end

    ##
    # Generates initial agent settings. These settings will be read by Bosh Agent from Bosh Registry on a target
    # server. Disk conventions in Bosh Agent for OpenStack are:
    # - system disk: /dev/sda
    # - ephemeral disk: /dev/sdb
    # - persistent disks: /dev/sdc through /dev/sdz
    # As some kernels remap device names (from sd* to vd* or xvd*), Bosh Agent will lookup for the proper device name
    #
    # @param [String] server_name Name of the OpenStack server (will be picked
    #   up by agent to fetch registry settings)
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment Environment settings
    # @param [Boolean] has_ephemeral Has Ephemeral disk?
    # @return [Hash] Agent settings
    def initial_agent_settings(server_name, agent_id, network_spec, environment, has_ephemeral)
      settings = {
        'vm' => {
          'name' => server_name
        },
        'agent_id' => agent_id,
        'networks' => network_spec,
        'disks' => {
          'system' => '/dev/sda',
          'persistent' => {}
        }
      }

      settings['disks']['ephemeral'] = has_ephemeral ? '/dev/sdb' : nil
      settings['env'] = environment if environment
      settings.merge(@agent_properties)
    end

    ##
    # Updates the agent settings
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    def update_agent_settings(server)
      raise ArgumentError, 'Block is not provided' unless block_given?

      @logger.info("Updating settings for server `#{server.id}'...")
      settings = @registry.read_settings(server.name)
      yield settings
      @registry.update_settings(server.name, settings)
    end

    ##
    # Soft reboots an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [void]
    def soft_reboot(server)
      @logger.info("Soft rebooting server `#{server.id}'...")
      with_openstack { server.reboot }
      wait_resource(server, :active, :state)
    end

    ##
    # Hard reboots an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [void]
    def hard_reboot(server)
      @logger.info("Hard rebooting server `#{server.id}'...")
      with_openstack { server.reboot(type = 'HARD') }
      wait_resource(server, :active, :state)
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    # @return [String] Device name
    def attach_volume(server, volume)
      @logger.info("Attaching volume `#{volume.id}' to server `#{server.id}'...")
      volume_attachments = with_openstack { server.volume_attachments }
      device = volume_attachments.find { |a| a['volumeId'] == volume.id }

      if device.nil?
        device_name = select_device_name(volume_attachments, first_device_name_letter(server))
        cloud_error('Server has too many disks attached') if device_name.nil?

        @logger.info("Attaching volume `#{volume.id}' to server `#{server.id}', device name is `#{device_name}'")
        with_openstack { volume.attach(server.id, device_name) }
        wait_resource(volume, :'in-use')
      else
        device_name = device['device']
        @logger.info("Volume `#{volume.id}' is already attached to server `#{server.id}' in `#{device_name}'. Skipping.")
      end

      device_name
    end

    ##
    # Select the first available device name
    #
    # @param [Array] volume_attachments Volume attachments
    # @param [String] first_device_name_letter First available letter for device names
    # @return [String] First available device name or nil is none is available
    def select_device_name(volume_attachments, first_device_name_letter)
      (first_device_name_letter..'z').each do |char|
        # Some kernels remap device names (from sd* to vd* or xvd*).
        device_names = ["/dev/sd#{char}", "/dev/vd#{char}", "/dev/xvd#{char}"]
        # Bosh Agent will lookup for the proper device name if we set it initially to sd*.
        return "/dev/sd#{char}" if volume_attachments.select { |v| device_names.include?( v['device']) }.empty?
        @logger.warn("`/dev/sd#{char}' is already taken")
      end

      nil
    end

    ##
    # Returns the first letter to be used on device names
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [String] First available letter
    def first_device_name_letter(server)
      letter = "#{FIRST_DEVICE_NAME_LETTER}"
      return letter if server.flavor.nil?
      return letter unless server.flavor.has_key?('id')
      flavor = with_openstack { @openstack.flavors.find { |f| f.id == server.flavor['id'] } }
      return letter if flavor.nil?

      letter.succ! if flavor_has_ephemeral_disk?(flavor)
      letter.succ! if flavor_has_swap_disk?(flavor)
      letter.succ! if @openstack_properties['config_drive'] == 'disk'
      letter
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    # @return [void]
    def detach_volume(server, volume)
      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}'...")
      volume_attachments = with_openstack { server.volume_attachments }
      attachment = volume_attachments.find { |a| a['volumeId'] == volume.id }
      if attachment
        with_openstack { volume.detach(server.id, attachment['id']) }
        wait_resource(volume, :available)
      else
        @logger.info("Disk `#{volume.id}' is not attached to server `#{server.id}'. Skipping.")
      end
    end

    ##
    # Compares actual server security groups with those specified at the network spec
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Array] specified_sg_names Security groups specified at the network spec
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If the security groups change, we need to recreate the VM as you can't
    # change the security group of a running server, so we need to send the InstanceUpdater a request to do it for us
    def compare_security_groups(server, specified_sg_names)
      actual_sg_names = with_openstack { server.security_groups }.collect { |sg| sg.name }

      unless actual_sg_names.sort == specified_sg_names.sort
        raise Bosh::Clouds::NotSupported,
              'security groups change requires VM recreation: %s to %s' %
              [actual_sg_names.join(', '), specified_sg_names.join(', ')]
      end
    end

    ##
    # Compares actual server private IP addresses with the IP address specified at the network spec
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Array] specified_ip_addresses IP addresses specified at the network spec (if Manual network)
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If the IP address change, we need to recreate the VM as you can't
    # change the IP address of a running server, so we need to send the InstanceUpdater a request to do it for us
    def compare_private_ip_addresses(server, specified_ip_addresses)
      actual_ip_addresses = with_openstack { server.private_ip_addresses }

      unless specified_ip_addresses.empty? || actual_ip_addresses.sort == specified_ip_addresses.sort
        raise Bosh::Clouds::NotSupported,
              'IP address change requires VM recreation: %s to %s' %
              [actual_ip_addresses.join(', '), specified_ip_addresses.join(', ')]
      end
    end

    ##
    # Checks if the OpenStack flavor has ephemeral disk
    #
    # @param [Fog::Compute::OpenStack::Flavor] OpenStack flavor
    # @return [Boolean] true if flavor has ephemeral disk, false otherwise
    def flavor_has_ephemeral_disk?(flavor)
      flavor.ephemeral.nil? || flavor.ephemeral.to_i <= 0 ? false : true
    end

    ##
    # Checks if the OpenStack flavor has swap disk
    #
    # @param [Fog::Compute::OpenStack::Flavor] OpenStack flavor
    # @return [Boolean] true if flavor has swap disk, false otherwise
    def flavor_has_swap_disk?(flavor)
      flavor.swap.nil? || flavor.swap.to_i <= 0 ? false : true
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
        cloud_error('Extracting stemcell root image failed. Check task debug log for details.')
      end
      root_image = File.join(tmp_dir, 'root.img')
      unless File.exists?(root_image)
        cloud_error('Root image is missing from stemcell archive')
      end
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    # @return [void]
    # @raise [ArgumentError] if options are not valid
    def validate_options
      schema = Membrane::SchemaParser.parse do
        {
          'openstack' => {
            'auth_url' => String,
            'username' => String,
            'api_key' => String,
            'tenant' => String,
            optional('region') => String,
            optional('endpoint_type') => String,
            optional('state_timeout') => Numeric,
            optional('stemcell_public_visibility') => enum(String, bool),
            optional('connection_options') => Hash,
            optional('boot_from_volume') => bool,
            optional('default_key_name') => String,
            optional('default_security_groups') => [String],
            optional('wait_resource_poll_interval') => Integer,
            optional('config_drive') => enum('disk', 'cdrom'),
          },
          'registry' => {
            'endpoint' => String,
            'user' => String,
            'password' => String,
          },
          optional('agent') => Hash,
        }
      end
      schema.validate(@options)
    rescue Membrane::SchemaValidationError => e
      raise ArgumentError, "Invalid OpenStack cloud properties: #{e.inspect}"
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

    def normalize_options(options)
      unless options.kind_of?(Hash)
        raise ArgumentError, "Invalid OpenStack cloud properties: Hash expected, received #{options}"
      end
      # we only care about two top-level fields
      options = hash_filter(options.dup) { |key| OPTION_KEYS.include?(key) }
      # nil values should be treated the same as missing keys (makes validating optional fields easier)
      delete_entries_with_nil_keys(options)
    end

    def hash_filter(hash)
      copy = {}
      hash.each do |key, value|
        copy[key] = value if yield(key)
      end
      copy
    end

    def delete_entries_with_nil_keys(options)
      options.each do |key, value|
        if value == nil
          options.delete(key)
        elsif value.kind_of?(Hash)
          options[key] = delete_entries_with_nil_keys(value.dup)
        end
      end
      options
    end
  end
end
