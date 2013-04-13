# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud

  class Cloud < Bosh::Cloud
    include Helpers

    # default maximum number of times to retry an AWS API call
    DEFAULT_MAX_RETRIES = 2
    DEFAULT_EC2_ENDPOINT = "ec2.amazonaws.com"
    DEFAULT_ELB_ENDPOINT = "elasticloadbalancing.amazonaws.com"
    METADATA_TIMEOUT = 5 # in seconds
    DEVICE_POLL_TIMEOUT = 60 # in seconds

    attr_reader :ec2
    attr_reader :registry
    attr_reader :options
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
      @aws_region = @aws_properties["region"]
      @registry_properties = @options["registry"]

      @default_key_name = @aws_properties["default_key_name"]
      @fast_path_delete = @aws_properties["fast_path_delete"]

      aws_params = {
          :access_key_id => @aws_properties["access_key_id"],
          :secret_access_key => @aws_properties["secret_access_key"],
          :ec2_endpoint => @aws_properties["ec2_endpoint"] || default_ec2_endpoint,
          :elb_endpoint => @aws_properties["elb_endpoint"] || default_elb_endpoint,
          :max_retries => @aws_properties["max_retries"] || DEFAULT_MAX_RETRIES,
          :logger => @aws_logger
      }

      aws_params[:proxy_uri] = @aws_properties["proxy_uri"] if @aws_properties["proxy_uri"]

      registry_endpoint = @registry_properties["endpoint"]
      registry_user = @registry_properties["user"]
      registry_password = @registry_properties["password"]

      # AWS Ruby SDK is threadsafe but Ruby autoload isn't,
      # so we need to trigger eager autoload while constructing CPI
      AWS.eager_autoload!

      AWS.config(aws_params)
      @ec2 = AWS::EC2.new

      # Registry updates are not really atomic in relation to
      # EC2 API calls, so they might get out of sync. Cloudcheck
      # is supposed to fix that.
      @registry = RegistryClient.new(registry_endpoint,
                                     registry_user,
                                     registry_password)

      @region = @ec2.regions[@aws_region]
      @az_selector = AvailabilityZoneSelector.new(@region, @aws_properties["default_availability_zone"])
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
    def create_vm(agent_id, stemcell_id, resource_pool, network_spec, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        # do this early to fail fast
        stemcell = Stemcell.find(@region, stemcell_id)

        begin
          instance_manager = InstanceManager.new(@region, registry, az_selector)
          instance = instance_manager.
              create(agent_id, stemcell_id, resource_pool, network_spec, (disk_locality || []), environment, @options)

          @logger.info("Creating new instance '#{instance.id}'")

          NetworkConfigurator.new(network_spec).configure(@region, instance)

          registry_settings = initial_agent_settings(
              agent_id,
              network_spec,
              environment,
              preformatted?(resource_pool),
              stemcell.root_device_name,
              @options['agent'] || {}
          )
          registry.update_settings(instance.id, registry_settings)

          instance.id
        rescue => e # is this rescuing too much?
          @logger.error(%Q[Failed to create instance: #{e.message}\n#{e.backtrace.join("\n")}])
          instance_manager.terminate(instance.id, @fast_path_delete) if instance
          raise e
        end
      end
    end

    def preformatted?(resource_pool)
      resource_pool["preformatted"]
    end

    ##
    # Delete EC2 instance ("terminate" in AWS language) and wait until
    # it reports as terminated
    # @param [String] instance_id EC2 instance id
    def delete_vm(instance_id)
      with_thread_name("delete_vm(#{instance_id})") do
        @logger.info("Deleting instance '#{instance_id}'")
        InstanceManager.new(@region, registry).terminate(instance_id, @fast_path_delete)
      end
    end

    ##
    # Reboot EC2 instance
    # @param [String] instance_id EC2 instance id
    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        InstanceManager.new(@region, registry).reboot(instance_id)
      end
    end

    ##
    # Has EC2 instance
    # @param [String] instance_id EC2 instance id
    def has_vm?(instance_id)
      with_thread_name("has_vm?(#{instance_id})") do
        InstanceManager.new(@region, registry).has_instance?(instance_id)
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

        if instance_id
          az = @az_selector.select_from_instance_id(instance_id)
        else
          az = @az_selector.random_availability_zone
        end

        # if the disk is created for an instance, use the same availability
        # zone as they must match
        volume_params = {
            :size => (size / 1024.0).ceil,
            :availability_zone => az
        }

        volume = @ec2.volumes.create(volume_params)
        @logger.info("Creating volume `#{volume.id}'")
        ResourceWait.for_volume(volume: volume, state: :available)

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

        @logger.info("Deleting volume `#{volume.id}'")

        tries = 10
        sleep_cb = ResourceWait.sleep_callback("Waiting for volume `#{volume.id}' to be deleted", tries)
        ensure_cb = Proc.new do |retries|
          cloud_error("Timed out waiting to delete volume `#{volume.id}'") if retries+1 == tries
        end
        error = AWS::EC2::Errors::Client::VolumeInUse

        Bosh::Common.retryable(tries: tries, sleep: sleep_cb, on: error, ensure: ensure_cb) do
          volume.delete
          true # return true to only retry on Exceptions
        end

        if @fast_path_delete
          begin
            TagManager.tag(volume, "Name", "to be deleted")
            @logger.info("Volume `#{disk_id}' has been marked for deletion")
          rescue AWS::EC2::Errors::InvalidVolume::NotFound
            # Once in a blue moon AWS if actually fast enough that the volume is already gone
            # when we get here, and if it is, our work here is done!
          end
          return
        end

        ResourceWait.for_volume(volume: volume, state: :deleted)

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

    # Take snapshot of disk
    # @param [String] disk_id disk id of the disk to take the snapshot of
    # @return [String] snapshot id
    def snapshot_disk(disk_id)
      with_thread_name("snapshot_disk(#{disk_id})") do
        volume = @ec2.volumes[disk_id]
        snapshot = volume.create_snapshot
        @logger.info("snapshot '#{snapshot.id}' of volume '#{disk_id}' created")
        snapshot.id
      end
    end

    # Delete a disk snapshot
    # @param [String] snapshot_id snapshot id to delete
    def delete_snapshot(snapshot_id)
      with_thread_name("delete_snapshot(#{snapshot_id})") do
        snapshot = @ec2.snapshots[snapshot_id]

        if snapshot.status == :in_use
          raise Bosh::Clouds::CloudError, "snapshot '#{snapshot.id}' can not be deleted as it is in use"
        end

        # loop and wait until available before deleting, in case the snapshot isn't
        # completed yet, as we don't wait when we take the snapshot
        ResourceWait.for_snapshot(snapshot: snapshot, state: :completed)

        snapshot.delete
        @logger.info("snapshot '#{snapshot_id}' deleted")
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

        instance = @ec2.instances[instance_id]

        actual_group_names = instance.security_groups.collect { |sg| sg.name }
        specified_group_names = extract_security_group_names(network_spec)
        new_group_names = specified_group_names.empty? ? Array(@aws_properties["default_security_groups"]) : specified_group_names

        # If the security groups change, we need to recreate the VM
        # as you can't change the security group of a running instance,
        # we need to send the InstanceUpdater a request to do it for us
        unless actual_group_names.sort == new_group_names.sort
          raise Bosh::Clouds::NotSupported,
                "security groups change requires VM recreation: %s to %s" %
                    [actual_group_names.join(", "), new_group_names.join(", ")]
        end

        NetworkConfigurator.new(network_spec).configure(@ec2, instance)

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
    def create_stemcell(image_path, stemcell_properties)
      # TODO: refactor into several smaller methods
      with_thread_name("create_stemcell(#{image_path}...)") do
        creator = StemcellCreator.new(@region, stemcell_properties)

        return creator.fake.id if creator.fake?

        begin
          # These three variables are used in 'ensure' clause
          instance = nil
          volume = nil

          # 1. Create and mount new EBS volume (2GB default)
          disk_size = stemcell_properties["disk"] || 2048
          volume_id = create_disk(disk_size, current_instance_id)
          volume = @ec2.volumes[volume_id]
          instance = @ec2.instances[current_instance_id]

          sd_name = attach_ebs_volume(instance, volume)
          ebs_volume = find_ebs_device(sd_name)

          @logger.info("Creating stemcell with: '#{volume.id}' and '#{stemcell_properties.inspect}'")
          creator.create(volume, ebs_volume, image_path).id
        rescue => e
          @logger.error(e)
          raise e
        ensure
          if instance && volume
            detach_ebs_volume(instance, volume, true)
            delete_disk(volume.id)
          end
        end
      end
    end

    # Delete a stemcell and the accompanying snapshots
    # @param [String] stemcell_id EC2 AMI name of the stemcell to be deleted
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        stemcell = Stemcell.find(@region, stemcell_id)
        stemcell.delete
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
        TagManager.tag(instance, key, value)
      end

      job = metadata[:job]
      index = metadata[:index]

      if job && index
        name = "#{job}/#{index}"
      elsif metadata[:compiling]
        name = "compiling/#{metadata[:compiling]}"
      end
      TagManager.tag(instance, "Name", name) if name
    rescue AWS::EC2::Errors::TagLimitExceeded => e
      @logger.error("could not tag #{instance.id}: #{e.message}")
    end

    # @note Not implemented in the AWS CPI
    def validate_deployment(old_manifest, new_manifest)
      # Not implemented in VSphere CPI as well
      not_implemented(:validate_deployment)
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

    private

    attr_reader :az_selector

    def update_agent_settings(instance)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      settings = registry.read_settings(instance.id)
      yield settings
      registry.update_settings(instance.id, settings)
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
        # work around AWS eventual (in)consistency
        Bosh::Common.retryable(tries: 10, on: AWS::EC2::Errors::IncorrectState) do
          new_attachment = volume.attach_to(instance, dev_name)
        end
        break
      end

      if new_attachment.nil?
        # TODO: better messaging?
        cloud_error("Instance has too many disks attached")
      end

      @logger.info("Attaching `#{volume.id}' to `#{instance.id}'")
      ResourceWait.for_attachment(attachment: new_attachment, state: :attached)

      device_name = new_attachment.device

      @logger.info("Attached `#{volume.id}' to `#{instance.id}', " \
                   "device name is `#{device_name}'")

      device_name
    end

    def detach_ebs_volume(instance, volume, force=false)
      mappings = instance.block_device_mappings.to_hash

      device_map = mappings.inject({}) do |hash, (device_name, attachment)|
        hash[attachment.volume.id] = device_name
        hash
      end

      if device_map[volume.id].nil?
        raise Bosh::Clouds::DiskNotAttached.new(true),
              "Disk `#{volume.id}' is not attached to instance `#{instance.id}'"
      end

      attachment = volume.detach_from(instance, device_map[volume.id], force: force)
      @logger.info("Detaching `#{volume.id}' from `#{instance.id}'")

      ResourceWait.for_attachment(attachment: attachment, state: :detached)
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    def validate_options
      required_keys = {
          "aws" => ["access_key_id", "secret_access_key", "region", "default_key_name"],
          "registry" => ["endpoint", "user", "password"],
      }

      missing_keys = []

      required_keys.each_pair do |key, values|
        values.each do |value|
          if (!@options.has_key?(key) || !@options[key].has_key?(value))
            missing_keys << "#{key}:#{value}"
          end
        end
      end

      raise ArgumentError, "missing configuration parameters > #{missing_keys.join(', ')}" unless missing_keys.empty?
    end

    def default_ec2_endpoint
      if @aws_region
        "ec2.#{@aws_region}.amazonaws.com"
      else
        DEFAULT_EC2_ENDPOINT
      end
    end

    def default_elb_endpoint
      if @aws_region
        "elasticloadbalancing.#{@aws_region}.amazonaws.com"
      else
        DEFAULT_ELB_ENDPOINT
      end
    end

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
    def initial_agent_settings(agent_id, network_spec, environment, preformatted, root_device_name, agent_properties)
      settings = {
          "vm" => {
              "name" => "vm-#{SecureRandom.uuid}"
          },
          "agent_id" => agent_id,
          "networks" => network_spec,
          "preformatted" => preformatted,
          "disks" => {
              "system" => root_device_name,
              "ephemeral" => "/dev/sdb",
              "persistent" => {}
          }
      }

      settings["env"] = environment if environment
      settings.merge(agent_properties)
    end
  end
end
