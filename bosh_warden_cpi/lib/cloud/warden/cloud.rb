module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Bosh::WardenCloud::Helpers

    DEFAULT_STEMCELL_ROOT = '/var/vcap/stemcell'
    DEFAULT_DISK_ROOT = '/var/vcap/store/disk'
    DEFAULT_FS_TYPE = 'ext4'
    DEFAULT_WARDEN_DEV_ROOT = '/warden-cpi-dev'
    DEFAULT_WARDEN_SOCK = '/tmp/warden.sock'

    attr_accessor :logger

    ##
    # Initialize BOSH Warden CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @logger = Bosh::Clouds::Config.logger

      @agent_properties = options.fetch('agent', {})
      @warden_properties = options.fetch('warden', {})
      @stemcell_properties = options.fetch('stemcell', {})
      @disk_properties = options.fetch('disk', {})

      setup_path
      @disk_utils = DiskUtils.new(@disk_root, @stemcell_root, @fs_type)
    end

    ##
    # Create a stemcell using stemcell image
    # @param [String] image_path local path to a stemcell image
    # @param [Hash] cloud_properties not used
    # return [String] stemcell id
    def create_stemcell(image_path, cloud_properties)
      not_used(cloud_properties)
      stemcell_id = uuid('stemcell')
      with_thread_name("create_stemcell(#{image_path}, _)") do
        @logger.info("Extracting stemcell from #{image_path} for #{stemcell_id}")
        @disk_utils.stemcell_unpack(image_path, stemcell_id)
        stemcell_id
      end
    end

    ##
    # Delete the stemcell
    # @param [String] id of the stemcell to be deleted
    # @return [void]
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id}, _)") do
        @disk_utils.stemcell_delete(stemcell_id)
        nil
      end
    end

    ##
    # Create a container in warden
    #
    # Limitaion: We don't support creating VM with multiple network nics.
    #
    # @param [String] agent_id UUID for bosh agent
    # @param [String] stemcell_id stemcell id
    # @param [Hash] resource_pool not used
    # @param [Hash] networks list of networks and their settings needed for this VM
    # @param [optional, String, Array] disk_locality not used
    # @param [optional, Hash] env environment that will be passed to this vm
    # @return [String] vm_id
    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks, disk_locality = nil, environment = nil)
      not_used(resource_pool)
      not_used(disk_locality)

      vm_handle = nil
      with_thread_name("create_vm(#{agent_id}, #{stemcell_id}, #{networks})") do
        stemcell_path = @disk_utils.stemcell_path(stemcell_id)
        vm_id = uuid('vm')

        raise ArgumentError, 'Not support more than 1 nics' if networks.size > 1
        cloud_error("Cannot find Stemcell(#{stemcell_id})") unless Dir.exist?(stemcell_path)

        # Create Container
        vm_handle = with_warden do |client|
          request = Warden::Protocol::CreateRequest.new
          request.handle = vm_id
          request.rootfs = stemcell_path
          if networks.first[1]['type'] != 'dynamic'
            request.network = networks.first[1]['ip']
          end
          request.bind_mounts = bind_mount_prepare(vm_id)
          response = client.call(request)
          response.handle
        end
        cloud_error("Cannot create vm with given handle #{vm_id}") unless vm_handle == vm_id

        # Agent settings
        env = generate_agent_env(vm_id, agent_id, networks, environment)
        set_agent_env(vm_id, env)
        start_agent(vm_id)
        vm_id
      end
    rescue => e
      destroy_container(vm_handle) if vm_handle
      raise e
    end

    ##
    # Deletes a VM
    #
    # @param [String] vm_id vm id
    # @return [void]
    def delete_vm(vm_id)
      with_thread_name("delete_vm(#{vm_id})") do
        if has_vm?(vm_id)
          destroy_container(vm_id)
          vm_bind_mount = File.join(@bind_mount_points, vm_id)
          sudo "umount #{vm_bind_mount}"
        end

        ephemeral_mount = File.join(@ephemeral_mount_points, vm_id)
        sudo "rm -rf #{ephemeral_mount}"
        vm_bind_mount = File.join(@bind_mount_points, vm_id)
        sudo "rm -rf #{vm_bind_mount}"
        nil
      end
    end

    ##
    # Checks if a VM exists
    #
    # @param [String] vm_id vm id
    # @return [Boolean] True if the vm exists

    def has_vm?(vm_id)
      with_thread_name("has_vm(#{vm_id})") do
        result = false
        handles = with_warden do |client|
          request = Warden::Protocol::ListRequest.new
          response = client.call(request)
          response.handles
        end
        unless handles.nil?
          result = handles.include?(vm_id)
        end
        result
      end
    end

    def reboot_vm(vm_id)
      # no-op
    end

    def configure_networks(vm_id, networks)
      # no-op
    end

    ##
    # Create a disk
    #
    # @param [Integer] size disk size in MB
    # @param [String] vm_locality vm id if known of the VM that this disk will
    #                 be attached to
    # @return [String] disk id
    def create_disk(size, vm_locality = nil)
      not_used(vm_locality)
      with_thread_name("create_disk(#{size}, _)") do
        disk_id = uuid('disk')
        @disk_utils.create_disk(disk_id, size)
        disk_id
      end
    end

    ##
    # Delete a disk
    #
    # @param [String] disk id
    # @return [void]
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        cloud_error("Cannot find disk #{disk_id}") unless has_disk?(disk_id)
        @disk_utils.delete_disk(disk_id)
        nil
      end
    end

    ##
    # Attach a disk to a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def attach_disk(vm_id, disk_id)
      with_thread_name("attach_disk(#{vm_id}, #{disk_id})") do
        cloud_error("Cannot find vm #{vm_id}") unless has_vm?(vm_id)
        cloud_error("Cannot find disk #{disk_id}") unless has_disk?(disk_id)

        vm_bind_mount = File.join(@bind_mount_points, vm_id)
        disk_dir = File.join(vm_bind_mount, disk_id)

        @disk_utils.mount_disk(disk_dir, disk_id)
        # Save device path into agent env settings
        env = get_agent_env(vm_id)
        env['disks']['persistent'][disk_id] = File.join(@warden_dev_root, disk_id)
        set_agent_env(vm_id, env)

        nil
      end
    end

    ##
    # Detach a disk from a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def detach_disk(vm_id, disk_id)
      with_thread_name("detach_disk(#{vm_id}, #{disk_id})") do

        cloud_error("Cannot find vm #{vm_id}") unless has_vm?(vm_id)
        cloud_error("Cannot find disk #{disk_id}") unless has_disk?(disk_id)

        vm_bind_mount = File.join(@bind_mount_points, vm_id)
        device_path = File.join(vm_bind_mount, disk_id)

        # umount the image file
        @disk_utils.umount_disk(device_path)
        # Save device path into agent env settings
        env = get_agent_env(vm_id)
        env['disks']['persistent'][disk_id] = nil
        set_agent_env(vm_id, env)

        nil
      end
    end

    private

    def has_disk?(disk_id)
      @disk_utils.disk_exist?(disk_id)
    end

    def not_used(*arg)
      # no-op
    end

    def setup_path
      @warden_unix_path = @warden_properties.fetch('unix_domain_path', DEFAULT_WARDEN_SOCK)
      @warden_dev_root = @disk_properties.fetch('warden_dev_root', DEFAULT_WARDEN_DEV_ROOT)
      @stemcell_root = @stemcell_properties.fetch('root', DEFAULT_STEMCELL_ROOT)

      @disk_root = @disk_properties.fetch('root', DEFAULT_DISK_ROOT)
      @fs_type = @disk_properties.fetch('fs', DEFAULT_FS_TYPE)

      @bind_mount_points = File.join(@disk_root, 'bind_mount_points')
      @ephemeral_mount_points = File.join(@disk_root, 'ephemeral_mount_point')
    end

    def bind_mount_prepare(vm_id)
      vm_bind_mount = File.join(@bind_mount_points, vm_id)
      FileUtils.mkdir_p(vm_bind_mount)
      vm_ephemeral_mount = File.join(@ephemeral_mount_points, vm_id)
      FileUtils.mkdir_p(vm_ephemeral_mount)

      # Make the bind mount point shareable
      sudo "mount --bind #{vm_bind_mount} #{vm_bind_mount}"
      sudo "mount --make-unbindable #{vm_bind_mount}"
      sudo "mount --make-shared #{vm_bind_mount}"

      bind_mount = Warden::Protocol::CreateRequest::BindMount.new
      bind_mount.src_path = vm_bind_mount
      bind_mount.dst_path = @warden_dev_root
      bind_mount.mode = Warden::Protocol::CreateRequest::BindMount::Mode::RW

      ephemeral_mount = Warden::Protocol::CreateRequest::BindMount.new
      ephemeral_mount.src_path = vm_ephemeral_mount
      ephemeral_mount.dst_path = '/var/vcap/data'
      ephemeral_mount.mode = Warden::Protocol::CreateRequest::BindMount::Mode::RW

      return [bind_mount, ephemeral_mount]
    end

    def destroy_container(container_id)
      with_warden do |client|
        request = Warden::Protocol::DestroyRequest.new
        request.handle = container_id
        client.call(request)
      end
    end

  end
end
