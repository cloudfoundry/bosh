module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = '/tmp/warden.sock'
    DEFAULT_STEMCELL_ROOT = '/var/vcap/stemcell'
    DEFAULT_DISK_ROOT = '/var/vcap/store/disk'
    DEFAULT_FS_TYPE = 'ext4'
    DEFAULT_WARDEN_DEV_ROOT = '/warden-cpi-dev'
    DEFAULT_SETTINGS_FILE = '/var/vcap/bosh/settings.json'
    UMOUNT_GUARD_RETRIES = 60
    UMOUNT_GUARD_SLEEP = 3

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

      setup_warden
      setup_stemcell
      setup_disk

    end

    ##
    # Create a stemcell using stemcell image
    # This method simply untar the stemcell image to a local directory. Warden
    # can use the rootfs within the image as a base fs.
    # @param [String] image_path local path to a stemcell image
    # @param [Hash] cloud_properties not used
    # return [String] stemcell id
    def create_stemcell(image_path, cloud_properties)
      not_used(cloud_properties)

      stemcell_id = uuid('stemcell')
      stemcell_dir = stemcell_path(stemcell_id)

      with_thread_name("create_stemcell(#{image_path}, _)") do

        # Extract to tarball
        @logger.info("Extracting stemcell from #{image_path} to #{stemcell_dir}")
        FileUtils.mkdir_p(stemcell_dir)

        # This command needs priviledge because the stemcell contains device files,
        # which cannot be untared without priviledge
        raise "#{image_path} not exist for creating stemcell" unless File.exist?(image_path)
        sudo "tar -C #{stemcell_dir} -xzf #{image_path} 2>&1"

        stemcell_id
      end
    rescue => e
      sudo "rm -rf #{stemcell_dir}"

      raise e
    end

    ##
    # Delete the stemcell
    # @param [String] id of the stemcell to be deleted
    # @return [void]
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id}, _)") do
        stemcell_dir = stemcell_path(stemcell_id)
        sudo "rm -rf #{stemcell_dir}"

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
                  networks, disk_locality = nil, env = nil)
      not_used(resource_pool)
      not_used(disk_locality)
      not_used(env)

      vm_handle = nil
      with_thread_name("create_vm(#{agent_id}, #{stemcell_id}, #{networks})") do

        stemcell_path = stemcell_path(stemcell_id)
        vm_id = uuid('vm')

        if networks.size > 1
          raise ArgumentError, 'Not support more than 1 nics'
        end

        unless Dir.exist?(stemcell_path)
          cloud_error("Cannot find Stemcell(#{stemcell_id})")
        end

        vm_bind_mount = File.join(@bind_mount_points, vm_id)
        FileUtils.mkdir_p(vm_bind_mount)
        vm_ephemeral_mount = File.join(@ephemeral_mount_points, vm_id)
        FileUtils.mkdir_p(vm_ephemeral_mount)

        # Make the bind mount point shareable
        sudo "mount --bind #{vm_bind_mount} #{vm_bind_mount}"
        sudo "mount --make-unbindable #{vm_bind_mount}"
        sudo "mount --make-shared #{vm_bind_mount}"

        # Create Container
        handle = with_warden do |client|
          request = Warden::Protocol::CreateRequest.new
          request.handle = vm_id
          request.rootfs = stemcell_path
          if networks.first[1]['type'] != 'dynamic'
            request.network = networks.first[1]['ip']
          end

          bind_mount = Warden::Protocol::CreateRequest::BindMount.new
          bind_mount.src_path = vm_bind_mount
          bind_mount.dst_path = @warden_dev_root
          bind_mount.mode = Warden::Protocol::CreateRequest::BindMount::Mode::RW

          ephemeral_mount = Warden::Protocol::CreateRequest::BindMount.new
          ephemeral_mount.src_path = vm_ephemeral_mount
          ephemeral_mount.dst_path = '/var/vcap/data'
          ephemeral_mount.mode = Warden::Protocol::CreateRequest::BindMount::Mode::RW

          request.bind_mounts = [bind_mount, ephemeral_mount]
          response = client.call(request)
          response.handle
        end

        vm_handle = handle
        cloud_error("Cannot create vm with given handle #{vm_id}") unless handle == vm_id

        # Agent settings
        env = generate_agent_env(vm_id, agent_id, networks)
        set_agent_env(vm_id, env)

        # Notice: It's a little hacky, but it's the way it is now.
        #
        # Warden has a default white list for devices. By default, all the loop
        # devices cannot be read/written/mknod. We don't want to change the
        # warden behavior, so we just manipulate the container cgroup directly.
        sudo "bash -c 'echo \"b 7:* rwm\" > /tmp/warden/cgroup/devices/instance-#{handle}/devices.allow'"

        # Start bosh agent
        with_warden do |client|
          request = Warden::Protocol::SpawnRequest.new
          request.handle = handle
          request.privileged = true
          request.script = '/usr/sbin/runsvdir-start'
          client.call(request)
        end
        vm_id
      end
    rescue => e
      if vm_handle
        with_warden do |client|
          request = Warden::Protocol::DestroyRequest.new
          request.handle = vm_handle
          client.call(request)
        end
      end
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
          with_warden do |client|
            request = Warden::Protocol::DestroyRequest.new
            request.handle = vm_id
            client.call(request)
          end
          vm_bind_mount = File.join(@bind_mount_points, vm_id)
          sudo "umount #{vm_bind_mount}"
        end

        ephemeral_mount = File.join(@ephemeral_mount_points, vm_id)
        sudo "rm -rf #{ephemeral_mount}"
        vm_bind_mount = File.join(@bind_mount_points, vm_id.to_s)
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
      image_file = nil
      raise ArgumentError, 'disk size <= 0' unless size > 0

      with_thread_name("create_disk(#{size}, _)") do
        disk_id = uuid('disk')
        image_file = image_path(disk_id)

        FileUtils.touch(image_file)
        File.truncate(image_file, size << 20) # 1 MB == 1<<20 Byte
        sh "/sbin/mkfs -t #{@fs_type} -F #{image_file} 2>&1"

        disk_id
      end
    rescue => e
      FileUtils.rm_f image_file if image_file
      raise e
    end

    ##
    # Delete a disk
    #
    # @param [String] disk id
    # @return [void]
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do

        cloud_error("Cannot find disk #{disk_id}") unless has_disk?(disk_id)

        # Remove image file
        FileUtils.rm_f image_path(disk_id)

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

        # Create a device file inside warden container
        vm_bind_mount = File.join(@bind_mount_points, vm_id)
        disk_dir = File.join(vm_bind_mount, disk_id)
        FileUtils.mkdir_p(disk_dir)

        disk_img = image_path(disk_id)
        sudo "mount #{disk_img} #{disk_dir} -o loop"

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
        umount_guard device_path
        # Save device path into agent env settings
        env = get_agent_env(vm_id)
        env['disks']['persistent'][disk_id] = nil
        set_agent_env(vm_id, env)

        nil
      end
    end

    def validate_deployment(old_manifest, new_manifest)
      # no-op
    end

    private

    def has_disk?(disk_id)
      File.exist?(image_path(disk_id))
    end

    def mount_entry(partition)
      File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
    end

    # Retry the umount for GUARD_RETRIES +1  times
    def umount_guard(mountpoint)
      umount_attempts = UMOUNT_GUARD_RETRIES

      loop do
        return if mount_entry(mountpoint).nil?
        sudo "umount #{mountpoint}" do |result|
          if result.success?
            return
          elsif umount_attempts != 0
            sleep UMOUNT_GUARD_SLEEP
            umount_attempts -= 1
          else
            raise "Failed to umount #{mountpoint}: #{result.output}"
          end
        end
      end
    end

    def not_used(*arg)
      # no-op
    end

    def stemcell_path(stemcell_id)
      File.join(@stemcell_root, stemcell_id)
    end

    def image_path(disk_id)
      File.join(@disk_root, "#{disk_id}.img")
    end

    def setup_warden
      @warden_unix_path = @warden_properties['unix_domain_path'] || DEFAULT_WARDEN_SOCK
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties['root'] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

    def setup_disk
      @disk_root = @disk_properties['root'] || DEFAULT_DISK_ROOT
      @fs_type = @disk_properties['fs'] || DEFAULT_FS_TYPE

      @warden_dev_root = @disk_properties['warden_dev_root'] || DEFAULT_WARDEN_DEV_ROOT
      @bind_mount_points = File.join(@disk_root, 'bind_mount_points')
      @ephemeral_mount_points = File.join(@disk_root, 'ephemeral_mount_point')
      FileUtils.mkdir_p(@disk_root)
    end

    def with_warden
      client = Warden::Client.new(@warden_unix_path)
      client.connect

      ret = yield client

      ret
    ensure
      client.disconnect if client
    end

    def agent_settings_file
      DEFAULT_SETTINGS_FILE
    end

    def generate_agent_env(vm_id, agent_id, networks)
      vm_env = {
        'name' => vm_id,
        'id' => vm_id
      }

      env = {
        'vm' => vm_env,
        'agent_id' => agent_id,
        'networks' => networks,
        'disks' => { 'persistent' => {} },
      }
      env.merge!(@agent_properties)
      env
    end

    def get_agent_env(handle)
      body = with_warden do |client|
        request = Warden::Protocol::RunRequest.new
        request.handle = handle
        request.privileged = true
        request.script = "cat #{agent_settings_file}"

        client.call(request).stdout
      end

      env = Yajl::Parser.parse(body)
      env
    end

    def set_agent_env(handle, env)
      tempfile = Tempfile.new('settings')
      tempfile.write(Yajl::Encoder.encode(env))
      tempfile.close

      tempfile_in = "/tmp/#{rand(100_000)}"

      # Here we copy the setting file to temp file in container, then mv it to
      # /var/vcap/bosh by privileged user.
      with_warden do |client|
        request = Warden::Protocol::CopyInRequest.new
        request.handle = handle
        request.src_path = tempfile.path
        request.dst_path = tempfile_in

        client.call(request)

        request = Warden::Protocol::RunRequest.new
        request.handle = handle
        request.privileged = true
        request.script = "mv #{tempfile_in} #{agent_settings_file}"

        client.call(request)
      end

      tempfile.unlink
    end

  end
end
