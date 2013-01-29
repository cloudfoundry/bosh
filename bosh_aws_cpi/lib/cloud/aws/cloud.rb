# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud

  class Cloud < Bosh::Cloud
    include Helpers

    # default maximum number of times to retry an AWS API call
    DEFAULT_MAX_RETRIES = 2
    # default availability zone for instances and disks
    DEFAULT_AVAILABILITY_ZONE = "us-east-1a"
    DEFAULT_EC2_ENDPOINT = "ec2.amazonaws.com"
    METADATA_TIMEOUT = 5 # in seconds
    DEVICE_POLL_TIMEOUT = 60 # in seconds
    MAX_TAG_KEY_LENGTH = 127
    MAX_TAG_VALUE_LENGTH = 255

    attr_reader :ec2
    attr_reader :registry
    attr_accessor :logger

    ##
    # Initialize BOSH AWS CPI. The contents of sub-hashes are defined in the {file:README.md}
    # @param [Hash] options CPI options
    # @option options [Hash] aws AWS specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @aws_logger = @logger # TODO make configurable

      @agent_properties = @options["agent"] || {}
      @aws_properties = @options["aws"]
      @aws_region = @aws_properties.delete("region")
      @registry_properties = @options["registry"]

      @default_key_name = @aws_properties["default_key_name"]
      @default_security_groups = @aws_properties["default_security_groups"]

      aws_params = {
        :access_key_id => @aws_properties["access_key_id"],
        :secret_access_key => @aws_properties["secret_access_key"],
        :ec2_endpoint => @aws_properties["ec2_endpoint"] || default_ec2_endpoint,
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

      @aki_picker = AKIPicker.new(@ec2)
      @metadata_lock = Mutex.new
    end

    ##
    # Create an EC2 instance and wait until it's in running state
    # @param [String] agent_id agent id associated with new VM
    # @param [String] stemcell_id AMI id of the stemcell used to
    #  create the new instance
    # @param [Hash] resource_pool resource pool specification
    # @param [Hash] network_spec network specification, if it contains
    #  security groups they must already exist
    # @param [optional, Array] disk_locality list of disks that
    #   might be attached to this instance in the future, can be
    #   used as a placement hint (i.e. instance will only be created
    #   if resource pool availability zone is the same as disk
    #   availability zone)
    # @param [optional, Hash] environment data to be merged into
    #   agent settings
    # @return [String] EC2 instance id of the new virtual machine
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        network_configurator = NetworkConfigurator.new(network_spec)

        security_groups =
          network_configurator.security_groups(@default_security_groups)
        @logger.debug("using security groups: #{security_groups.join(', ')}")

        response = @ec2.client.describe_images(:image_ids => [stemcell_id])
        images_set = response.images_set
        if images_set.empty?
          cloud_error("no stemcell info for #{stemcell_id}")
        end
        root_device_name = images_set.first.root_device_name

        instance_params = {
          :image_id => stemcell_id,
          :count => 1,
          :key_name => resource_pool["key_name"] || @default_key_name,
          :security_groups => security_groups,
          :instance_type => resource_pool["instance_type"],
          :user_data => Yajl::Encoder.encode(user_data(network_spec))
        }

        instance_params[:availability_zone] =
          select_availability_zone(disk_locality,
          resource_pool["availability_zone"])

        @logger.info("Creating new instance...")
        instance = @ec2.instances.create(instance_params)

        @logger.info("Creating new instance `#{instance.id}'")
        wait_resource(instance, :running)

        network_configurator.configure(@ec2, instance)

        settings = initial_agent_settings(agent_id, network_spec, environment,
                                          root_device_name)
        @registry.update_settings(instance.id, settings)

        instance.id
      end
    end

    ##
    # Delete EC2 instance ("terminate" in AWS language) and wait until
    # it reports as terminated
    # @param [String] instance_id EC2 instance id
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
    # Reboot EC2 instance
    # @param [String] instance_id EC2 instance id
    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        instance = @ec2.instances[instance_id]
        soft_reboot(instance)
      end
    end

    ##
    # Creates a new EBS volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] instance_id EC2 instance id
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

        # if the disk is created for an instance, use the same availability
        # zone as they must match
        if instance_id
          instance = @ec2.instances[instance_id]
          availability_zone = instance.availability_zone
        else
          availability_zone = default_availability_zone
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
    # Delete EBS volume
    # @param [String] disk_id EBS volume id
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
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

    # Attach an EBS volume to an EC2 instance
    # @param [String] instance_id EC2 instance id of the virtual machine to attach the disk to
    # @param [String] disk_id EBS volume id of the disk to attach
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
        @logger.info("Attached `#{disk_id}' to `#{instance_id}'")
      end
    end

    # Detach an EBS volume from an EC2 instance
    # @param [String] instance_id EC2 instance id of the virtual machine to detach the disk from
    # @param [String] disk_id EBS volume id of the disk to detach
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

    # Configure network for an EC2 instance
    # @param [String] instance_id EC2 instance id
    # @param [Hash] network_spec network properties
    # @raise [Bosh::Clouds:NotSupported] if the security groups change
    def configure_networks(instance_id, network_spec)
      with_thread_name("configure_networks(#{instance_id}, ...)") do
        @logger.info("Configuring `#{instance_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")

        network_configurator = NetworkConfigurator.new(network_spec)
        instance = @ec2.instances[instance_id]

        actual = instance.security_groups.collect {|sg| sg.name }.sort
        new = network_configurator.security_groups(@default_security_groups)

        # If the security groups change, we need to recreate the VM
        # as you can't change the security group of a running instance,
        # we need to send the InstanceUpdater a request to do it for us
        unless actual == new
          raise Bosh::Clouds::NotSupported,
                "security groups change requires VM recreation: %s to %s" %
                [actual.join(", "), new.join(", ")]
        end

        network_configurator.configure(@ec2, instance)

        update_agent_settings(instance) do |settings|
          settings["networks"] = network_spec
        end
      end
    end

    ##
    # Creates a new EC2 AMI using stemcell image.
    # This method can only be run on an EC2 instance, as image creation
    # involves creating and mounting new EBS volume as local block device.
    # @param [String] image_path local filesystem path to a stemcell image
    # @param [Hash] cloud_properties AWS-specific stemcell properties
    # @option cloud_properties [String] kernel_id
    #   AKI, auto-selected based on the region, unless specified
    # @option cloud_properties [String] root_device_name
    #   block device path (e.g. /dev/sda1), provided by the stemcell manifest, unless specified
    # @option cloud_properties [String] architecture
    #   instruction set architecture (e.g. x86_64), provided by the stemcell manifest,
    #   unless specified
    # @option cloud_properties [String] disk (2048)
    #   root disk size
    # @return [String] EC2 AMI name of the stemcell
    def create_stemcell(image_path, cloud_properties)
      # TODO: refactor into several smaller methods
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
          # These three variables are used in 'ensure' clause
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

          params = image_params(cloud_properties, snapshot.id)
          image = @ec2.images.create(params)
          wait_resource(image, :available, :state)

          tag(image, "Name", params[:description]) if params[:description]

          image.id
        rescue => e
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

    # Delete a stemcell and the accompanying snapshots
    # @param [String] stemcell_id EC2 AMI name of the stemcell to be deleted
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        snapshots = []
        image = @ec2.images[stemcell_id]

        image.block_device_mappings.each do |device, map|
          id = map[:snapshot_id]
          if id
            @logger.debug("queuing snapshot #{id} for deletion")
            snapshots << id
          end
        end

        image.deregister

        snapshots.each do |id|
          @logger.info("cleaning up snapshot #{id}")
          snapshot = @ec2.snapshots[id]
          snapshot.delete
        end
      end
    end

    # Add tags to an instance. In addition to the suplied tags,
    # it adds a 'Name' tag as it is shown in the AWS console.
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Hash] metadata metadata key/value pairs
    # @return [void]
    def set_vm_metadata(vm, metadata)
      instance = @ec2.instances[vm]

      # TODO should we clear existing tags that don't exist in metadata?
      metadata.each_pair do |key, value|
        tag(instance, key, value)
      end

      # should deployment name be included too?
      job = metadata[:job]
      index = metadata[:index]
      tag(instance, "Name", "#{job}/#{index}") if job && index
    rescue AWS::EC2::Errors::TagLimitExceeded => e
      @logger.error("could not tag #{instance.id}: #{e.message}")
    end

    # @note Not implemented in the AWS CPI
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
    # @note this is a private method that is public to make it easier to test
    def select_availability_zone(volumes, resource_pool_az)
      if volumes && !volumes.empty?
        disks = volumes.map { |vid| @ec2.volumes[vid] }
        ensure_same_availability_zone(disks, resource_pool_az)
        disks.first.availability_zone
      else
        resource_pool_az || default_availability_zone
      end
    end

    # ensure all supplied availability zones are the same
    # @note this is a private method that is public to make it easier to test
    def ensure_same_availability_zone(disks, default)
      zones = disks.map { |disk| disk.availability_zone }
      zones << default if default
      zones.uniq!
      cloud_error "can't use multiple availability zones: %s" %
        zones.join(", ") unless zones.size == 1 || zones.empty?
    end

    private

    # add a tag to something
    def tag(taggable, key, value)
      trimmed_key = key[0..(MAX_TAG_KEY_LENGTH - 1)]
      trimmed_value = value[0..(MAX_TAG_VALUE_LENGTH - 1)]
      taggable.add_tag(trimmed_key, :value => trimmed_value)
    rescue AWS::EC2::Errors::InvalidParameterValue => e
      @logger.error("could not tag #{taggable.id}: #{e.message}")
    end

    # Prepare EC2 user data
    # @param [Hash] network_spec network specification
    # @return [Hash] EC2 user data
    def user_data(network_spec)
      data = {}

      data["registry"] = { "endpoint" => @registry.endpoint }

      with_dns(network_spec) do |servers|
        data["dns"] = { "nameserver" => servers }
      end

      data
    end

    # extract dns server list from network spec and yield the the list
    # @param [Hash] network_spec network specification for instance
    # @yield [Array]
    def with_dns(network_spec)
      network_spec.each_value do |properties|
        if properties["dns"]
          yield properties["dns"]
          return
        end
      end
    end

    def image_params(cloud_properties, snapshot_id)
      root_device_name = cloud_properties["root_device_name"]
      architecture = cloud_properties["architecture"]

      params = {
          :name => "BOSH-#{generate_unique_name}",
          :architecture => architecture,
          :kernel_id => find_aki(architecture, root_device_name),
          :root_device_name =>  root_device_name,
          :block_device_mappings => {
              "/dev/sda" => { :snapshot_id => snapshot_id },
              "/dev/sdb" => "ephemeral0"
          }
      }

      # old stemcells doesn't have name & version
      if cloud_properties["name"] && cloud_properties["version"]
        name = "#{cloud_properties['name']} #{cloud_properties['version']}"
        params[:description] = name
      end

      params
    end

    def find_aki(architecture, root_device_name)
      @aki_picker.pick(architecture, root_device_name)
    end

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
    # @param [String] root_device_name root device, e.g. /dev/sda1
    # @return [Hash]
    def initial_agent_settings(agent_id, network_spec, environment,
                               root_device_name)
      settings = {
        "vm" => {
          "name" => "vm-#{generate_unique_name}"
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
        "disks" => {
          "system" => root_device_name,
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

      wait_resource(attachment, :detached) do |error|
        if error.is_a? AWS::Core::Resource::NotFound
          @logger.info("attachment is no longer found, assuming it to be detached")
          :detached
        end
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

      @logger.debug("stemcell copy output:\n#{out}")
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

    def default_ec2_endpoint
      if @aws_region
        "ec2.#{@aws_region}.amazonaws.com"
      else
        DEFAULT_EC2_ENDPOINT
      end
    end

    def default_availability_zone
      if @aws_region
        "#{@aws_region}b"
      else
        DEFAULT_AVAILABILITY_ZONE
      end
    end

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end
  end

end
