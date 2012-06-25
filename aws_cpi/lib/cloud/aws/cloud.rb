# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud

  class Cloud < Bosh::Cloud
    include Helpers

    DEFAULT_MAX_RETRIES = 2
    DEFAULT_AVAILABILITY_ZONE = "us-east-1a"
    DEFAULT_EC2_ENDPOINT = "ec2.amazonaws.com"
    METADATA_TIMEOUT = 5 # seconds
    DEVICE_POLL_TIMEOUT = 60 # seconds

    DEFAULT_AKI = "aki-825ea7eb"

    # UBUNTU_10_04_32_BIT_US_EAST_EBS = "ami-3e9b4957"
    # UBUNTU_10_04_32_BIT_US_EAST = "ami-809a48e9"

    attr_reader :ec2
    attr_reader :registry
    attr_accessor :logger

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
        :ec2_endpoint => @aws_properties["ec2_endpoint"] || DEFAULT_EC2_ENDPOINT,
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
    # @param [Hash] network_spec Network specification, if it contains
    #  security groups they must be existing
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

        security_groups =
          network_configurator.security_groups(@default_security_groups)
        @logger.debug("using security groups: #{security_groups.join(', ')}")

        instance_params = {
          :image_id => stemcell_id,
          :count => 1,
          :key_name => resource_pool["key_name"] || @default_key_name,
          :security_groups => security_groups,
          :instance_type => resource_pool["instance_type"],
          :user_data => Yajl::Encoder.encode(user_data)
        }

        instance_params[:availability_zone] =
          select_availability_zone(disk_locality,
          resource_pool["availability_zone"])

        @logger.info("Creating new instance...")
        instance = @ec2.instances.create(instance_params)

        @logger.info("Creating new instance `#{instance.id}'")
        wait_resource(instance, :running)

        network_configurator.configure(@ec2, instance)

        settings = initial_agent_settings(agent_id, network_spec, environment)
        @registry.update_settings(instance.id, settings)

        instance.id
      end
    end

    ##
    # Terminates EC2 instance and waits until it reports as terminated
    # @param [String] instance_id Running instance id
    def delete_vm(instance_id)
      with_thread_name("delete_vm(#{instance_id})") do
        instance = @ec2.instances[instance_id]

        instance.terminate

        begin
          # TODO: should this be done before or after deleting VM?
          @logger.info("Deleting instance settings for `#{instance.id}'")
          @registry.delete_settings(instance.id)

          @logger.info("Deleting instance `#{instance.id}'")
          wait_resource(instance, :terminated)
        rescue AWS::EC2::Errors::InvalidInstanceID::NotFound
          # It's OK, just means that instance has already been deleted
        end
      end
    end

    ##
    # Reboots EC2 instance
    # @param [String] instance_id Running instance id
    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        instance = @ec2.instances[instance_id]
        soft_reboot(instance)
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

        if size < 1024
          cloud_error("AWS CPI minimum disk size is 1 GiB")
        end

        if size > 1024 * 1000
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
        @logger.info("Creating volume `#{volume.id}'")
        wait_resource(volume, :available)

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

        begin
          @logger.info("Deleting volume `#{volume.id}'")
          wait_resource(volume, :deleted)
        rescue AWS::EC2::Errors::InvalidVolume::NotFound
          # It's OK, just means the volume has already been deleted
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
          # 1. Create and mount new EBS volume (2GB default)
          disk_size = cloud_properties["disk"] || 2048
          volume_id = create_disk(disk_size, current_instance_id)
          volume = @ec2.volumes[volume_id]
          instance = @ec2.instances[current_instance_id]

          sd_name = attach_ebs_volume(instance, volume)
          ebs_volume = find_ebs_device(sd_name)

          # 2. Copy image to new EBS volume
          @logger.info("Copying stemcell disk image to '#{ebs_volume}'")
          copy_root_image(image_path, ebs_volume)

          # 3. Create snapshot and then an image using this snapshot
          snapshot = volume.create_snapshot
          wait_resource(snapshot, :completed)

          image_params = {
            :name => "BOSH-#{generate_unique_name}",
            :architecture => "x86_64",
            :kernel_id => cloud_properties["kernel_id"] || DEFAULT_AKI,
            :root_device_name => "/dev/sda",
            :block_device_mappings => {
              "/dev/sda" => { :snapshot_id => snapshot.id },
              "/dev/sdb" => "ephemeral0"
            }
          }

          image = @ec2.images.create(image_params)
          wait_resource(image, :available, :state)

          image.id
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

    # Selects the availability zone to use from a list of disk volumes,
    # resource pool availability zone (if any) and the default availability
    # zone.
    # @param [Hash] volumes volume ids to attach to the vm
    # @param [String] resource_pool_az availability zone specified in
    #   the resource pool (may be nil)
    # @return [String] availability zone to use
    def select_availability_zone(volumes, resource_pool_az)
      if volumes && !volumes.empty?
        disks = volumes.map { |vid| @ec2.volumes[vid] }
        ensure_same_availability_zone(disks, resource_pool_az)
        disks.first.availability_zone
      else
        resource_pool_az || DEFAULT_AVAILABILITY_ZONE
      end
    end

    # ensure all supplied availability zones are the same
    def ensure_same_availability_zone(disks, default)
      zones = disks.map { |disk| disk.availability_zone }
      zones << default if default
      zones.uniq!
      cloud_error "can't use multiple availability zones: %s" %
        zones.join(", ") unless zones.size == 1 || zones.empty?
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
      # TODO once we upgrade the aws-sdk gem to > 1.3.9, we need to use:
      # instance.block_device_mappings.to_hash.keys
      device_names = Set.new(instance.block_device_mappings.to_hash.keys)
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

      @logger.info("Attaching `#{volume.id}' to `#{instance.id}'")
      wait_resource(new_attachment, :attached)

      device_name = new_attachment.device

      @logger.info("Attached `#{volume.id}' to `#{instance.id}', " \
                   "device name is `#{device_name}'")

      device_name
    end

    def detach_ebs_volume(instance, volume)
      # TODO once we upgrade the aws-sdk gem to > 1.3.9, we need to use:
      # instance.block_device_mappings.to_hash.keys
      mappings = instance.block_device_mappings.to_hash

      device_map = mappings.inject({}) do |hash, (device_name, attachment)|
        hash[attachment.volume.id] = device_name
        hash
      end

      if device_map[volume.id].nil?
        cloud_error("Disk `#{volume.id}' is not attached " \
                    "to instance `#{instance.id}'")
      end

      attachment = volume.detach_from(instance, device_map[volume.id])
      @logger.info("Detaching `#{volume.id}' from `#{instance.id}'")

      begin
        wait_resource(attachment, :detached)
      rescue AWS::Core::Resource::NotFound
        # It's OK, just means attachment is gone by now
      end
    end

    # This method tries to execute the helper script stemcell-copy
    # as root using sudo, since it needs to write to the ebs_volume.
    # If stemcell-copy isn't available, it falls back to writing directly
    # to the device, which is used in the micro bosh deployer.
    # The stemcell-copy script must be in the PATH of the user running
    # the director, and needs sudo privileges to execute without
    # password.
    def copy_root_image(image_path, ebs_volume)
      path = ENV["PATH"]

      if stemcell_copy = has_stemcell_copy(path)
        @logger.debug("copying stemcell using stemcell-copy script")
        # note that is is a potentially dangerous operation, but as the
        # stemcell-copy script sets PATH to a sane value this is safe
        out = `sudo #{stemcell_copy} #{image_path} #{ebs_volume} 2>&1`
      else
        @logger.info("falling back to using dd to copy stemcell")
        out = `tar -xzf #{image_path} -O root.img | dd of=#{ebs_volume} 2>&1`
      end

      unless $?.exitstatus == 0
        cloud_error("Unable to copy stemcell root image, " \
                    "exit status #{$?.exitstatus}: #{out}")
      end
    end

    # checks if the stemcell-copy script can be found in
    # the current PATH
    def has_stemcell_copy(path)
      path.split(":").each do |dir|
        stemcell_copy = File.join(dir, "stemcell-copy")
        return stemcell_copy if File.exist?(stemcell_copy)
      end
      nil
    end

    def find_ebs_device(sd_name)
      xvd_name = sd_name.gsub(/^\/dev\/sd/, "/dev/xvd")

      DEVICE_POLL_TIMEOUT.times do
        if File.blockdev?(sd_name)
          return sd_name
        elsif File.blockdev?(xvd_name)
          return xvd_name
        end
        sleep(1)
      end

      cloud_error("Cannot find EBS volume on current instance")
    end

    ##
    # Soft reboots EC2 instance
    # @param [AWS::EC2::Instance] instance EC2 instance
    def soft_reboot(instance)
      # There is no trackable status change for the instance being
      # rebooted, so it's up to CPI client to keep track of agent
      # being ready after reboot.
      instance.reboot
    end

    ##
    # Hard reboots EC2 instance
    # @param [AWS::EC2::Instance] instance EC2 instance
    def hard_reboot(instance)
      # N.B. This will only work with ebs-store instances,
      # as instance-store instances don't support stop/start.
      instance.stop

      @logger.info("Stopping instance `#{instance.id}'")
      wait_resource(instance, :stopped)

      instance.start
      @logger.info("Starting instance `#{instance.id}'")
      wait_resource(instance, :running)
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
