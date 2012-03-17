# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AWSCloud

  class Cloud < Bosh::Cloud
    include Helpers

    DEFAULT_MAX_RETRIES = 2
    DEFAULT_AVAILABILITY_ZONE = "us-east-1a"
    METADATA_TIMEOUT = 5 # seconds
    DEVICE_POLL_TIMEOUT = 60 # seconds

    DEFAULT_AKI = "aki-825ea7eb"

    # UBUNTU_10_04_32_BIT_US_EAST_EBS = "ami-3e9b4957"
    # UBUNTU_10_04_32_BIT_US_EAST = "ami-809a48e9"

    attr_reader :ec2
    attr_reader :registry

    ##
    # Initialize BOSH AWS CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @aws_logger = @logger # TODO make configurable

      @agent_properties = @options["agent"] || {}
      @aws_properties = @options["aws"]
      @registry_properties = @options["registry"]

      @default_key_name = @aws_properties["default_key_name"]
      @default_security_groups = @aws_properties["default_security_groups"]

      aws_params = {
        :access_key_id => @aws_properties["access_key_id"],
        :secret_access_key => @aws_properties["secret_access_key"],
        :max_retries => @aws_properties["max_retries"] || DEFAULT_MAX_RETRIES,
        :logger => @aws_logger
      }

      registry_endpoint = @registry_properties["endpoint"]
      registry_user = @registry_properties["user"]
      registry_password = @registry_properties["password"]

      # AWS Ruby SDK is threadsafe but Ruby autoload isn't,
      # so we need to trigger eager autoload while constructing CPI
      AWS.eager_autoload!
      @ec2 = AWS::EC2.new(aws_params)

      # Registry updates are not really atomic in relation to
      # EC2 API calls, so they might get out of sync. Cloudcheck
      # is supposed to fix that.
      @registry = RegistryClient.new(registry_endpoint,
                                     registry_user,
                                     registry_password)

      @metadata_lock = Mutex.new
    end

    ##
    # Creates EC2 instance and waits until it's in running state
    # @param [String] agent_id Agent id associated with new VM
    # @param [String] stemcell_id AMI id that will be used
    #   to power on new instance
    # @param [Hash] resource_pool Resource pool specification
    # @param [Hash] network_spec Network specification
    # @param [optional, Array] disk_locality List of disks that
    #   might be attached to this instance in the future, can be
    #   used as a placement hint (i.e. instance will only be created
    #   if resource pool availability zone is the same as disk
    #   availability zone)
    # @param [optional, Hash] environment Data to be merged into
    #   agent settings
    #
    # @return [String] created instance id
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        network_configurator = NetworkConfigurator.new(network_spec)

        user_data = {
          "registry" => {
            "endpoint" => @registry.endpoint
          }
        }

        if disk_locality
          # TODO: use as hint for availability zones
          @logger.debug("Disk locality is ignored by AWS CPI")
        end

        instance_params = {
          :image_id => stemcell_id,
          :count => 1,
          :key_name => resource_pool["key_name"] || @default_key_name,
          # TODO: lookup security groups in network spec
          :security_groups => @default_security_groups || [],
          :instance_type => resource_pool["instance_type"],
          :user_data => Yajl::Encoder.encode(user_data)
        }

        availability_zone = resource_pool["availability_zone"]
        if availability_zone
          instance_params[:availability_zone] = availability_zone
        end

        @logger.info("Creating new instance...")
        instance = @ec2.instances.create(instance_params)
        state = instance.status

        @logger.info("Creating new instance `#{instance.id}', " \
                     "state is `#{state}'")

        wait_resource(instance, state, :running)

        network_configurator.configure(@ec2, instance)

        settings = initial_agent_settings(agent_id, network_spec, environment)
        @registry.update_settings(instance.id, settings)

        instance.id
      end
    end

    ##
    # Terminates EC2 instance and waits until it reports as terminated
    # @param [String] vm_id Running instance id
    def delete_vm(instance_id)
      with_thread_name("delete_vm(#{instance_id})") do
        instance = @ec2.instances[instance_id]

        instance.terminate
        state = instance.status

        # TODO: should this be done before or after deleting VM?
        @logger.info("Deleting instance settings for `#{instance.id}'")
        @registry.delete_settings(instance.id)

        @logger.info("Deleting instance `#{instance.id}', " \
                     "state is `#{state}'")

        wait_resource(instance, state, :terminated)
      end
    end

    ##
    # Reboots EC2 instance and waits until it is running
    # @param [String] instance_id Running instance id
    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        instance = @ec2.instances[instance_id]
        # FIXME soft reboot doesn't seem to work with aws-sdk
        # @instance.reboot

        # The following will only work with EBS-root instances,
        # so our assumption is that we have one.
        instance.stop
        state = instance.status

        @logger.info("Stopping instance `#{instance.id}', " \
                     "state is `#{state}'")

        wait_resource(instance, state, :stopped)

        instance.start
        state = instance.status

        @logger.info("Starting instance `#{instance.id}', " \
                     "state is `#{state}'")

        wait_resource(instance, state, :running)
      end
    end

    ##
    # Creates a new EBS volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] instance_id vm id
    #        of the VM that this disk will be attached to
    # @return [String] created EBS volume id
    def create_disk(size, instance_id = nil)
      with_thread_name("create_disk(#{size}, #{instance_id})") do
        unless size.kind_of?(Integer)
          raise ArgumentError, "disk size needs to be an integer"
        end

        if (size < 1024)
          cloud_error("AWS CPI minimum disk size is 1 GiB")
        end

        if (size > 1024 * 1000)
          cloud_error("AWS CPI maximum disk size is 1 TiB")
        end

        if instance_id
          instance = @ec2.instances[instance_id]
          availability_zone = instance.availability_zone
        else
          availability_zone = DEFAULT_AVAILABILITY_ZONE
        end

        volume_params = {
          :size => (size / 1024.0).ceil,
          :availability_zone => availability_zone
        }

        volume = @ec2.volumes.create(volume_params)
        state = volume.state

        @logger.info("Creating volume `#{volume.id}', " \
                     "state is `#{state}'")

        wait_resource(volume, state, :available)

        volume.id
      end
    end

    ##
    # Deletes EBS volume
    # @param [String] disk_id volume id
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    # @return nil
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        volume = @ec2.volumes[disk_id]
        state = volume.state

        if state != :available
          cloud_error("Cannot delete volume `#{volume.id}', state is #{state}")
        end

        volume.delete
        state = volume.state

        @logger.info("Deleting volume `#{volume.id}', " \
                     "state is `#{state}'")

        begin
          wait_resource(volume, state, :deleted)
        rescue AWS::EC2::Errors::InvalidVolume::NotFound
        end

        @logger.info("Volume `#{disk_id}' has been deleted")
      end
    end

    def attach_disk(instance_id, disk_id)
      with_thread_name("attach_disk(#{instance_id}, #{disk_id})") do
        instance = @ec2.instances[instance_id]
        volume = @ec2.volumes[disk_id]

        device_name = attach_ebs_volume(instance, volume)

        update_agent_settings(instance) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end
      end
    end

    def detach_disk(instance_id, disk_id)
      with_thread_name("detach_disk(#{instance_id}, #{disk_id})") do
        instance = @ec2.instances[instance_id]
        volume = @ec2.volumes[disk_id]

        update_agent_settings(instance) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
        end

        detach_ebs_volume(instance, volume)

        @logger.info("Detached `#{disk_id}' from `#{instance_id}'")
      end
    end

    def configure_networks(instance_id, network_spec)
      with_thread_name("configure_networks(#{instance_id}, ...)") do
        @logger.info("Configuring `#{instance_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")

        network_configurator = NetworkConfigurator.new(network_spec)
        instance = @ec2.instances[instance_id]

        network_configurator.configure(@ec2, instance)

        update_agent_settings(instance) do |settings|
          settings["networks"] = network_spec
        end
      end
    end

    ##
    # Creates a new AMI using stemcell image.
    # This method can only be run on an EC2 instance, as image creation
    # involves creating and mounting new EBS volume as local block device.
    # @param [String] image_path local filesystem path to a stemcell image
    # @param [Hash] cloud_properties CPI-specific properties
    def create_stemcell(image_path, cloud_properties)
      # TODO: refactor into several smaller methods
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
          # These two variables are used in 'ensure' clause
          instance = nil
          volume = nil
          # 1. Create and mount new EBS volume (2GB)
          volume_id = create_disk(2048, current_instance_id)
          volume = @ec2.volumes[volume_id]
          instance = @ec2.instances[current_instance_id]

          sd_name = attach_ebs_volume(instance, volume)
          xvd_name = sd_name.gsub(/^\/dev\/sd/, "/dev/xvd")
          ebs_volume = nil

          DEVICE_POLL_TIMEOUT.times do
            if File.blockdev?(sd_name)
              ebs_volume = sd_name
              break
            elsif File.blockdev?(xvd_name)
              ebs_volume = xvd_name
              break
            end
            sleep(1)
          end

          if ebs_volume.nil?
            cloud_error("Cannot find EBS volume on current instance")
          end

          # 2. Copy image to new EBS volume
          Dir.mktmpdir do |tmp_dir|
            @logger.info("Extracting stemcell to `#{tmp_dir}'")
            output = `tar -C #{tmp_dir} -xzf #{image_path} 2>&1`
            if $?.exitstatus != 0
              cloud_error("Failed to unpack stemcell root image" \
                          "tar exit status #{$?.exitstatus}: #{output}")
            end

            root_image = File.join(tmp_dir, "root.img")
            unless File.exists?(root_image)
              cloud_error("Root image is missing from stemcell archive")
            end

            Dir.chdir(tmp_dir) do
              dd_out = `dd if=root.img of=#{ebs_volume} 2>&1`
              if $?.exitstatus != 0
                cloud_error("Unable to copy stemcell root image, " \
                            "dd exit status #{$?.exitstatus}: " \
                            "#{dd_out}")
              end
            end

            # 3. Create snapshot and then an image using this snapshot
            snapshot = volume.create_snapshot
            wait_resource(snapshot, snapshot.status, :completed)

            image_params = {
              :name => "BOSH-#{generate_unique_name}",
              :architecture => "x86_64",
              :kernel_id => DEFAULT_AKI,
              :root_device_name => "/dev/sda",
              :block_device_mappings => {
                "/dev/sda" => { :snapshot_id => snapshot.id },
                "/dev/sdb" => "ephemeral0"
              }
            }

            image = @ec2.images.create(image_params)
            wait_resource(image, image.state, :available, :state)

            image.id
          end
        rescue => e
          # TODO: delete snapshot?
          @logger.error(e)
          raise e
        ensure
          if instance && volume
            detach_ebs_volume(instance, volume)
            delete_disk(volume.id)
          end
        end
      end
    end

    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        image = @ec2.images[stemcell_id]
        image.deregister
      end
    end

    def validate_deployment(old_manifest, new_manifest)
      # Not implemented in VSphere CPI as well
      not_implemented(:validate_deployment)
    end

    private

    ##
    # Generates initial agent settings. These settings will be read by agent
    # from AWS registry (also a BOSH component) on a target instance. Disk
    # conventions for amazon are:
    # system disk: /dev/sda
    # ephemeral disk: /dev/sdb
    # EBS volumes can be configured to map to other device names later (sdf
    # through sdp, also some kernels will remap sd* to xvd*).
    #
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment
    # @return [Hash]
    def initial_agent_settings(agent_id, network_spec, environment)
      settings = {
        "vm" => {
          "name" => "vm-#{generate_unique_name}"
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
        "disks" => {
          "system" => "/dev/sda",
          "ephemeral" => "/dev/sdb",
          "persistent" => {}
        }
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    def update_agent_settings(instance)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      settings = @registry.read_settings(instance.id)
      yield settings
      @registry.update_settings(instance.id, settings)
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Reads current instance id from EC2 metadata. We are assuming
    # instance id cannot change while current process is running
    # and thus memoizing it.
    def current_instance_id
      @metadata_lock.synchronize do
        return @current_instance_id if @current_instance_id

        client = HTTPClient.new
        client.connect_timeout = METADATA_TIMEOUT
        # Using 169.254.169.254 is an EC2 convention for getting
        # instance metadata
        uri = "http://169.254.169.254/1.0/meta-data/instance-id/"

        response = client.get(uri)
        unless response.status == 200
          cloud_error("Instance metadata endpoint returned " \
                      "HTTP #{response.status}")
        end

        @current_instance_id = response.body
      end

    rescue HTTPClient::TimeoutError
      cloud_error("Timed out reading instance metadata, " \
                  "please make sure CPI is running on EC2 instance")
    end

    def attach_ebs_volume(instance, volume)
      device_names = Set.new(instance.block_device_mappings.keys)
      new_attachment = nil

      ("f".."p").each do |char| # f..p is what console suggests
        # Some kernels will remap sdX to xvdX, so agent needs
        # to lookup both (sd, then xvd)
        dev_name = "/dev/sd#{char}"
        if device_names.include?(dev_name)
          @logger.warn("`#{dev_name}' on `#{instance.id}' is taken")
          next
        end
        new_attachment = volume.attach_to(instance, dev_name)
        break
      end

      if new_attachment.nil?
        # TODO: better messaging?
        cloud_error("Instance has too many disks attached")
      end

      state = new_attachment.status

      @logger.info("Attaching `#{volume.id}' to #{instance.id}, " \
                   "state is #{state}'")

      wait_resource(new_attachment, state, :attached)
      device_name = new_attachment.device

      @logger.info("Attached `#{volume.id}' to `#{instance.id}', " \
                   "device name is `#{device_name}'")

      device_name
    end

    def detach_ebs_volume(instance, volume)
      mappings = instance.block_device_mappings

      device_map = mappings.inject({}) do |hash, (device_name, attachment)|
        hash[attachment.volume.id] = device_name
        hash
      end

      if device_map[volume.id].nil?
        cloud_error("Disk `#{volume.id}' is not attached " \
                    "to instance `#{instance.id}'")
      end

      attachment = volume.detach_from(instance, device_map[volume.id])
      state = attachment.status

      @logger.info("Detaching `#{volume.id}' from `#{instance.id}', " \
                   "state is #{state}'")

      begin
        wait_resource(attachment, state, :detached)
      rescue AWS::Core::Resource::NotFound
        # It's OK, just means attachment is gone when we're asking for state
      end
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    def validate_options
      unless @options.has_key?("aws") &&
          @options["aws"].is_a?(Hash) &&
          @options["aws"]["access_key_id"] &&
          @options["aws"]["secret_access_key"]
        raise ArgumentError, "Invalid AWS configuration parameters"
      end

      unless @options.has_key?("registry") &&
          @options["registry"].is_a?(Hash) &&
          @options["registry"]["endpoint"] &&
          @options["registry"]["user"] &&
          @options["registry"]["password"]
        raise ArgumentError, "Invalid registry configuration parameters"
      end
    end

  end

end
