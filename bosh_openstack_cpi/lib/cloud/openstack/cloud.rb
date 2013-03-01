# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  # BOSH OpenStack CPI
  class Cloud < Bosh::Cloud
    include Helpers

    attr_reader :openstack
    attr_reader :registry
    attr_reader :glance
    attr_accessor :logger

    ##
    # Creates a new BOSH OpenStack CPI
    #
    # @param [Hash] options CPI options
    # @option options [Hash] openstack OpenStack specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options["agent"] || {}
      @openstack_properties = @options["openstack"]
      @registry_properties = @options["registry"]

      @default_key_name = @openstack_properties["default_key_name"]
      @default_security_groups = @openstack_properties["default_security_groups"]

      openstack_params = {
        :provider => "OpenStack",
        :openstack_auth_url => @openstack_properties["auth_url"],
        :openstack_username => @openstack_properties["username"],
        :openstack_api_key => @openstack_properties["api_key"],
        :openstack_tenant => @openstack_properties["tenant"],
        :openstack_region => @openstack_properties["region"]
      }
      @openstack = Fog::Compute.new(openstack_params)

      glance_params = {
        :provider => "OpenStack",
        :openstack_auth_url => @openstack_properties["auth_url"],
        :openstack_username => @openstack_properties["username"],
        :openstack_api_key => @openstack_properties["api_key"],
        :openstack_tenant => @openstack_properties["tenant"],
        :openstack_region => @openstack_properties["region"],
        :openstack_endpoint_type => @openstack_properties["endpoint_type"] ||
                                    "publicURL"
      }
      @glance = Fog::Image.new(glance_params)

      registry_endpoint = @registry_properties["endpoint"]
      registry_user = @registry_properties["user"]
      registry_password = @registry_properties["password"]
      @registry = RegistryClient.new(registry_endpoint,
                                     registry_user,
                                     registry_password)

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
    # @option cloud_properties [optional, String] kernel_id UUID of the kernel
    #   image stored at OpenStack
    # @option cloud_properties [optional, String] kernel_file Name of the
    #   kernel image file provided at the stemcell archive
    # @option cloud_properties [optional, String] ramdisk_id UUID of the
    #   ramdisk image stored at OpenStack
    # @option cloud_properties [optional, String] ramdisk_file Name of the
    #   ramdisk image file provided at the stemcell archive
    # @return [String] OpenStack image UUID of the stemcell
    def create_stemcell(image_path, cloud_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
          Dir.mktmpdir do |tmp_dir|
            @logger.info("Extracting stemcell to `#{tmp_dir}'...")
            image_name = "BOSH-#{generate_unique_name}"

            # 1. Unpack image to temp directory
            unpack_image(tmp_dir, image_path)
            root_image = File.join(tmp_dir, "root.img")
        
            # 2. If image contains a kernel file, upload it to glance service
            kernel_id = nil
            if cloud_properties["kernel_id"]
              kernel_id = cloud_properties["kernel_id"]
            elsif cloud_properties["kernel_file"]
              kernel_image = File.join(tmp_dir, cloud_properties["kernel_file"])
              unless File.exists?(kernel_image)
                cloud_error("Kernel image " \
                            "#{cloud_properties['kernel_file']} " \
                            "is missing from stemcell archive")
              end
              kernel_params = {
                :name => "#{image_name}-AKI",
                :disk_format => "aki",
                :container_format => "aki",
                :location => kernel_image,
                :properties => {
                  :stemcell => image_name
                }
              }
              @logger.info("Uploading kernel image...")
              kernel_id = upload_image(kernel_params)
            end

            # 3. If image contains a ramdisk file, upload it to glance service
            ramdisk_id = nil
            if cloud_properties["ramdisk_id"]
              ramdisk_id = cloud_properties["ramdisk_id"]
            elsif cloud_properties["ramdisk_file"]
              ramdisk_image = File.join(tmp_dir, cloud_properties["ramdisk_file"])
              unless File.exists?(ramdisk_image)
                cloud_error("Ramdisk image " \
                            "#{cloud_properties['ramdisk_file']} " \
                            "is missing from stemcell archive")
              end
              ramdisk_params = {
                :name => "#{image_name}-ARI",
                :disk_format => "ari",
                :container_format => "ari",
                :location => ramdisk_image,
                :properties => {
                  :stemcell => image_name
                }
              }
              @logger.info("Uploading ramdisk image...")
              ramdisk_id = upload_image(ramdisk_params)
            end

            # 4. Upload image using Glance service
            image_params = {
              :name => image_name,
              :disk_format => cloud_properties["disk_format"],
              :container_format => cloud_properties["container_format"],
              :location => root_image,
              :is_public => true
            }
            image_properties = {}
            image_properties[:kernel_id] = kernel_id if kernel_id
            image_properties[:ramdisk_id] = ramdisk_id if ramdisk_id
            if cloud_properties["name"]
              image_properties[:stemcell_name] = cloud_properties["name"]
            end
            if cloud_properties["version"]
              image_properties[:stemcell_version] = cloud_properties["version"]
            end
            unless image_properties.empty?
              image_params[:properties] = image_properties
            end
            @logger.info("Uploading image...")
            upload_image(image_params)
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
        image = @glance.images.find_by_id(stemcell_id)
        if image
          kernel_id = image.properties["kernel_id"]
          if kernel_id
            kernel = @glance.images.find_by_id(kernel_id)
            if kernel && kernel.properties["stemcell"]
              if kernel.properties["stemcell"] == image.name
                @logger.info("Deleting kernel `#{kernel_id}'...")
                kernel.destroy
                @logger.info("Kernel `#{kernel_id}' is now deleted")
              end
            end
          end

          ramdisk_id = image.properties["ramdisk_id"]
          if ramdisk_id
            ramdisk = @glance.images.find_by_id(ramdisk_id)
            if ramdisk && ramdisk.properties["stemcell"]
              if ramdisk.properties["stemcell"] == image.name
                @logger.info("Deleting ramdisk `#{ramdisk_id}'...")
                ramdisk.destroy
                @logger.info("Ramdisk `#{ramdisk_id}' is now deleted")
              end
            end
          end

          image.destroy
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
    # @param [Hash] networks list of networks and their settings needed for
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
        @logger.info("Creating new server...")
        server_name = "vm-#{generate_unique_name}"

        network_configurator = NetworkConfigurator.new(network_spec)
        security_groups =
          network_configurator.security_groups(@default_security_groups)
        @logger.debug("Using security groups: `#{security_groups.join(', ')}'")

        image = @openstack.images.find { |i| i.id == stemcell_id }
        if image.nil?
          cloud_error("Image `#{stemcell_id}' not found")
        end
        @logger.debug("Using image: `#{stemcell_id}'")

        flavor = @openstack.flavors.find { |f|
          f.name == resource_pool["instance_type"] }
        if flavor.nil?
          cloud_error("Flavor `#{resource_pool["instance_type"]}' not found")
        end
        @logger.debug("Using flavor: `#{resource_pool["instance_type"]}'")

        server_params = {
          :name => server_name,
          :image_ref => image.id,
          :flavor_ref => flavor.id,
          :key_name => resource_pool["key_name"] || @default_key_name,
          :security_groups => security_groups,
          :user_data => Yajl::Encoder.encode(user_data(server_name,
                                                       network_spec))
        }

        availability_zone = select_availability_zone(disk_locality,
                              resource_pool["availability_zone"])
        if availability_zone
          server_params[:availability_zone] = availability_zone
        end

        server = @openstack.servers.create(server_params)

        @logger.info("Creating new server `#{server.id}'...")
        wait_resource(server, :active, :state)

        @logger.info("Configuring network for server `#{server.id}'...")
        network_configurator.configure(@openstack, server)

        @logger.info("Updating settings for server `#{server.id}'...")
        settings = initial_agent_settings(server_name, agent_id, network_spec,
                                          environment)
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
        server = @openstack.servers.get(server_id)
        if server
          server.destroy
          wait_resource(server, :terminated, :state, true)

          @logger.info("Deleting settings for server `#{server.id}'...")
          @registry.delete_settings(server.name)
        else
          @logger.info("Server `#{server_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Reboots an OpenStack Server
    #
    # @param [String] server_id OpenStack server UUID
    # @return [void]
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = @openstack.servers.get(server_id)
        unless server
          cloud_error("Server `#{server_id}' not found")
        end
        soft_reboot(server)
      end
    end

    ##
    # Configures networking on existing OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [Hash] network_spec Raw network spec passed by director
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] if the security groups change
    def configure_networks(server_id, network_spec)
      with_thread_name("configure_networks(#{server_id}, ...)") do
        @logger.info("Configuring `#{server_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")

        network_configurator = NetworkConfigurator.new(network_spec)
        server = @openstack.servers.get(server_id)

        sg = @openstack.list_security_groups(server_id).body["security_groups"]
        actual = sg.collect { |s| s["name"] }.sort
        new = network_configurator.security_groups(@default_security_groups)

        # If the security groups change, we need to recreate the VM
        # as you can't change the security group of a running server,
        # we need to send the InstanceUpdater a request to do it for us
        unless actual == new
          raise Bosh::Clouds::NotSupported,
                "security groups change requires VM recreation: %s to %s" %
                [actual.join(", "), new.join(", ")]
        end

        network_configurator.configure(@openstack, server)

        update_agent_settings(server) do |settings|
          settings["networks"] = network_spec
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
    def create_disk(size, server_id = nil)
      with_thread_name("create_disk(#{size}, #{server_id})") do
        unless size.kind_of?(Integer)
          raise ArgumentError, "Disk size needs to be an integer"
        end

        if (size < 1024)
          cloud_error("Minimum disk size is 1 GiB")
        end

        if (size > 1024 * 1000)
          cloud_error("Maximum disk size is 1 TiB")
        end

        volume_params = {
          :name => "volume-#{generate_unique_name}",
          :description => "",
          :size => (size / 1024.0).ceil
        }

        if server_id
          server = @openstack.servers.get(server_id)
          if server && server.availability_zone
            volume_params[:availability_zone] = server.availability_zone
          end
        end

        @logger.info("Creating new volume...")
        volume = @openstack.volumes.create(volume_params)

        @logger.info("Creating new volume `#{volume.id}'...")
        wait_resource(volume, :available)

        volume.id.to_s
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
        volume = @openstack.volumes.get(disk_id)
        if volume
          state = volume.status
          if state.to_sym != :available
            cloud_error("Cannot delete volume `#{disk_id}', state is #{state}")
          end

          volume.destroy
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
        server = @openstack.servers.get(server_id)
        unless server
          cloud_error("Server `#{server_id}' not found")
        end
        volume = @openstack.volumes.get(disk_id)
        unless server
          cloud_error("Volume `#{disk_id}' not found")
        end

        device_name = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
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
        server = @openstack.servers.get(server_id)
        unless server
          cloud_error("Server `#{server_id}' not found")
        end
        volume = @openstack.volumes.get(disk_id)
        unless server
          cloud_error("Volume `#{disk_id}' not found")
        end

        detach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
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
        server = @openstack.servers.get(server_id)
        unless server
          cloud_error("Server `#{server_id}' not found")
        end

        metadata.each do |name, value|
          value = "" if value.nil? # value is required
          server.metadata.update(name => value)
        end
      end
    end

    ##
    # Validates the deployment
    #
    # @note Not implemented in the OpenStack CPI
    def validate_deployment(old_manifest, new_manifest)
      not_implemented(:validate_deployment)
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
      if volumes && !volumes.empty?
        disks = volumes.map { |vid| @openstack.volumes.get(vid) }
        ensure_same_availability_zone(disks, resource_pool_az)
        disks.first.availability_zone
      else
        resource_pool_az
      end
    end

    ##
    # Ensure all supplied availability zones are the same
    #
    # @param [Array] disks OpenStack volumes
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

    private

    ##
    # Generates an unique name
    #
    # @return [String] Unique name
    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Prepare server user data
    #
    # @param [String] server_name server name
    # @param [Hash] network_spec network specification
    # @return [Hash] server user data
    def user_data(server_name, network_spec)
      data = {}

      data["registry"] = { "endpoint" => @registry.endpoint }
      data["server"] = { "name" => server_name }

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
    # Generates initial agent settings. These settings will be read by agent
    # from OpenStack registry (also a BOSH component) on a target server. Disk
    # conventions for OpenStack are:
    # system disk: /dev/vda
    # ephemeral disk: /dev/ vdb
    # OpenStack volumes can be configured to map to other device names later
    # (vdc through vdz, also some kernels will remap vd* to xvd*).
    #
    # @param [String] server_name Name of the OpenStack server (will be picked
    #   up by agent to fetch registry settings)
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment Environment settings
    # @return [Hash] Agent settings
    def initial_agent_settings(server_name, agent_id, network_spec, environment)
      settings = {
        "vm" => {
          "name" => server_name
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
        "disks" => {
          "system" => "/dev/vda",
          "ephemeral" => "/dev/vdb",
          "persistent" => {}
        }
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    ##
    # Updates the agent settings
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    def update_agent_settings(server)
      unless block_given?
        raise ArgumentError, "Block is not provided"
      end

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
      server.reboot
      wait_resource(server, :active, :state)
    end

    ##
    # Hard reboots an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @return [void]
    def hard_reboot(server)
      @logger.info("Hard rebooting server `#{server.id}'...")
      server.reboot(type = 'HARD')
      wait_resource(server, :active, :state)
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    # @return [String] Device name
    def attach_volume(server, volume)
      volume_attachments = @openstack.get_server_volumes(server.id).
                           body['volumeAttachments']
      device_names = Set.new(volume_attachments.collect! { |v| v["device"] })

      new_attachment = nil
      ("c".."z").each do |char|
        dev_name = "/dev/vd#{char}"
        if device_names.include?(dev_name)
          @logger.warn("`#{dev_name}' on `#{server.id}' is taken")
          next
        end
        @logger.info("Attaching volume `#{volume.id}' to `#{server.id}', " \
                     "device name is `#{dev_name}'")
        if volume.attach(server.id, dev_name)
          wait_resource(volume, :"in-use")
          new_attachment = dev_name
        end
        break
      end

      if new_attachment.nil?
        cloud_error("Server has too many disks attached")
      end

      new_attachment
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    #
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    # @return [void]
    def detach_volume(server, volume)
      volume_attachments = @openstack.get_server_volumes(server.id).
                           body['volumeAttachments']
      device_map = volume_attachments.collect! { |v| v["volumeId"] }

      unless device_map.include?(volume.id)
        cloud_error("Disk `#{volume.id}' is not attached to " \
                    "server `#{server.id}'")
      end

      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}'...")
      volume.detach(server.id, volume.id)
      wait_resource(volume, :available)
    end

    ##
    # Uploads a new image to OpenStack via Glance
    #
    # @param [Hash] image_params Image params
    # @return [String] OpenStack image UUID
    def upload_image(image_params)
      @logger.info("Creating new image...")
      started_at = Time.now
      image = @glance.images.create(image_params)
      total = Time.now - started_at
      @logger.info("Created new image `#{image.id}', took #{total}s")

      image.id.to_s
    end

    ##
    # Unpacks a stemcell archive
    #
    # @param [String] tmp_dir Temporary directory
    # @param [String] image_path Local filesystem path to a stemcell image
    # @return [void]
    def unpack_image(tmp_dir, image_path)
      output = `tar -C #{tmp_dir} -xzf #{image_path} 2>&1`
      if $?.exitstatus != 0
        cloud_error("Failed to unpack stemcell root image" \
                    "tar exit status #{$?.exitstatus}: #{output}")
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
      unless @options["openstack"].is_a?(Hash) &&
          @options.has_key?("openstack") &&
          @options["openstack"]["auth_url"] &&
          @options["openstack"]["username"] &&
          @options["openstack"]["api_key"] &&
          @options["openstack"]["tenant"]
        raise ArgumentError, "Invalid OpenStack configuration parameters"
      end

      unless @options.has_key?("registry") &&
          @options["registry"].is_a?(Hash) &&
          @options["registry"]["endpoint"] &&
          @options["registry"]["user"] &&
          @options["registry"]["password"]
        raise ArgumentError, "Invalid registry configuration parameters"
      end
    end

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

  end
end
