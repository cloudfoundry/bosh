# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AWSCloud

  class Cloud < Bosh::Cloud
    include Helpers

    DEFAULT_MAX_RETRIES = 2
    DEFAULT_AVAILABILITY_ZONE = "us-east-1a"

    # UBUNTU_10_04_32_BIT_US_EAST_EBS = "ami-3e9b4957"
    # UBUNTU_10_04_32_BIT_US_EAST = "ami-809a48e9"

    attr_reader :ec2

    ##
    # Initialize BOSH AWS Cpi
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @aws_logger = @logger # TODO make configurable

      @agent_properties = @options["agent"]
      @aws_properties = @options["aws"]

      @default_key_name = @aws_properties["default_key_name"]
      @default_security_groups = @aws_properties["default_security_groups"]

      aws_params = {
        :access_key_id => @aws_properties["access_key_id"],
        :secret_access_key => @aws_properties["secret_access_key"],
        :max_retries => @aws_properties["max_retries"] || DEFAULT_MAX_RETRIES,
        :logger => @aws_logger
      }

      @ec2 = AWS::EC2.new(aws_params)
    end

    ##
    # Creates EC2 instance and waits until it's in running state
    # @param [String] agent_id Agent id associated with new VM
    # @param [String] stemcell_id AMI id that will be used
    #        to power on new instance
    # @param [Hash] resource_pool
    # @param [Hash] network_spec
    # @param [Array] disk_locality List of disks that are going to be attached
    #        to this instance, might be used as hint for placement
    # @param [Hash] environment
    #
    # @return [String] created instance id (to be saved by CPI user for
    #         later operations)
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do

        vm_name = "vm-#{generate_unique_name}"
        instance_type = resource_pool["instance_type"]

        key_name = resource_pool["key_name"]
        availability_zone = resource_pool["availability_zone"]

        user_data = initial_agent_env(vm_name, agent_id)
        user_data["env"] = environment if environment

        @logger.info("Creating new instance...")

        if disk_locality
          # TODO: use as hint for availability zones
          @logger.debug("Disk locality is ignored by AWS CPI")
        end

        if network_spec && network_spec.kind_of?(Hash) && network_spec.size > 0
          cloud_error("AWS CPI doesn't support resource pool " \
                      "network configuration")
        end

        instance_params = {
          :image_id => stemcell_id,
          :count => 1,
          :key_name => key_name || @default_key_name,
          # TODO: lookup security groups via network
          :security_groups => @default_security_groups,
          :instance_type => instance_type,
          :user_data => Yajl::Encoder.encode(user_data)
        }

        if availability_zone
          instance_params[:availability_zone] = availability_zone
        end

        instance = @ec2.instances.create(instance_params)

        state = instance.status

        @logger.info("Creating new instance `#{instance.id}', " \
                     "state is `#{state}'")

        wait_resource(instance, state, :running)

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
          cloud_error("AWS CPI minimum disk size is 1000 MiB")
        end

        if (size > 1024 * 1000)
          cloud_error("AWS CPI maximum disk size is 1 TiB")
        end

        if (size % 1024 != 0)
          cloud_error("AWS CPI disk size should be a multiple of 1024")
        end

        if instance_id
          instance = @ec2.instances[instance_id]
          availability_zone = instance.availability_zone
        else
          availability_zone = DEFAULT_AVAILABILITY_ZONE
        end

        volume_params = {
          :size => size / 1024,
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

        if volume.state != :available
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

        device_names = Set.new(instance.block_device_mappings.keys)
        new_attachment = nil

        ("f".."z").each do |char|
          dev_name = "/dev/sd#{char}"
          if device_names.include?(dev_name)
            @logger.warn("`#{dev_name}' on `#{instance.id}' is taken")
            next
          end
          new_attachment = volume.attach_to(instance, dev_name)
        end

        if new_attachment.nil?
          # TODO: better messaging?
          cloud_error("Instance has too many disks attached")
        end

        state = new_attachment.status

        @logger.info("Attaching `#{disk_id}' to #{instance_id}, " \
                     "state is #{state}'")

        wait_resource(new_attachment, state, :attached)
        device_name = new_attachment.device

        @logger.info("Attached `#{disk_id}' to `#{instance_id}', " \
                     "device name is `#{device_name}'")

        # TODO: update agent env with new disk mappings
      end
    end

    def detach_disk(instance_id, disk_id)
      with_thread_name("detach_disk(#{instance_id}, #{disk_id})") do
        instance = @ec2.instances[instance_id]
        volume = @ec2.volumes[disk_id]

        # TODO: update agent env with new disk mappings

        mappings = instance.block_device_mappings

        device_map = mappings.inject({}) do |hash, (device_name, attachment)|
          hash[attachment.volume.id] = device_name
          hash
        end

        if device_map[disk_id].nil?
          cloud_error("Disk `#{disk_id}' is not attached " \
                      "to instance `#{instance_id}'")
        end

        attachment = volume.detach_from(instance, device_map[disk_id])
        state = attachment.status

        @logger.info("Detaching `#{disk_id}' from `#{instance_id}', " \
                     "state is #{state}'")

        begin
          wait_resource(attachment, state, :detached)
        rescue AWS::Core::Resource::NotFound
          # It's OK, just means volume is gone when we're asking for state
        end

        @logger.info("Detached `#{disk_id}' from `#{instance_id}'")
      end
    end

    def configure_networks(vm_id, networks)
      not_implemented(:configure_networks)
    end

    def create_stemcell(image_path, cloud_properties)
      not_implemented(:create_stemcell)
    end

    def delete_stemcell(stemcell_id)
      not_implemented(:delete_stemcell)
    end

    def validate_deployment(old_manifest, new_manifest)
      # Not implemented in VSphere CPI as well
      not_implemented(:validate_deployment)
    end

    private

    ##
    # Generates agent environment. This environment will be read by agent
    # from EC2 user data on a target instance. Disk conventions for amazon
    # are:
    # system disk: /dev/sda1
    # ephemeral disk: /dev/sda2
    # EBS volumes can be configured to map to other device names later.
    #
    # @param [String] vm_name VM name (mostly for debugging purposes)
    # @param [String] agent_id Agent id (will be picked up by agent to
    #        assume its identity
    # @return [Hash] Agent environment (will be pushed to agent as user-data)
    #
    def initial_agent_env(vm_name, agent_id)
      # TODO inject registry endpoint
      env = {
        "vm" => {
          "name" => vm_name
        },
        "agent_id" => agent_id,
        "networks" => {},
        "disks" => {
          # TODO: can we guarantee it's sda1/sda2
          "system" => "sda1",
          "ephemeral" => "sda2",
          "persistent" => {}
        }
      }
      env.merge(@agent_properties)
    end

    def update_agent_env(instance)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      # TODO read data from registry
      new_env = yield current_env
      # TODO: update data in registry
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Checks if optioned passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    def validate_options
      unless @options.has_key?("aws") &&
          @options["aws"].is_a?(Hash) &&
          @options["aws"]["access_key_id"] &&
          @options["aws"]["secret_access_key"]
        raise ArgumentError, "Invalid AWS configuration parameters"
      end
    end

  end

end
