module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = "/tmp/warden.sock"
    DEFAULT_STEMCELL_ROOT = "/var/vcap/stemcell"
    DEFAULT_DISK_ROOT = "/var/vcap/store/disk"
    DEFAULT_FS_TYPE = "ext4"
    DEFAULT_POOL_SIZE = 128
    DEFAULT_POOL_START_NUMBER = 10
    DEFAULT_DEVICE_PREFIX = "/dev/sdz"

    DEFAULT_SETTINGS_FILE = "/var/vcap/bosh/settings.json"

    attr_accessor :logger

    ##
    # Initialize BOSH Warden CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @logger = Bosh::Clouds::Config.logger

      @agent_properties = options["agent"] || {}
      @warden_properties = options["warden"] || {}
      @stemcell_properties = options["stemcell"] || {}
      @disk_properties = options["disk"] || {}

      setup_warden
      setup_stemcell
      setup_disk

      setup_pool
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

      stemcell_id = uuid("stemcell")
      stemcell_dir = stemcell_path(stemcell_id)

      with_thread_name("create_stemcell(#{image_path}, _)") do

        # Extract to tarball
        @logger.info("Extracting stemcell from #{image_path} to #{stemcell_dir}")
        FileUtils.mkdir_p(stemcell_dir)

        # This command needs priviledge because the stemcell contains device files,
        # which cannot be untared without priviledge
        sudo "tar -C #{stemcell_dir} -xzf #{image_path} 2>&1"

        # TODO Verify if it is a valid stemcell

        stemcell_id
      end
    rescue => e
      sudo "rm -rf #{stemcell_dir}" rescue nil
      cloud_error(e)
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

      with_thread_name("create_vm(#{agent_id}, #{stemcell_id}, #{networks})") do

        stemcell_path = stemcell_path(stemcell_id)

        if networks.size > 1
          raise ArgumentError, "Not support more than 1 nics"
        end

        unless Dir.exist?(stemcell_path)
          raise ArgumentError, "Stemcell(#{stemcell_id}) not found"
        end

        vm = Models::VM.new

        # Create Container
        handle = with_warden do |client|
          request = Warden::Protocol::CreateRequest.new
          request.rootfs = File.join(stemcell_path, 'root')
          if networks.first[1]['type'] != 'dynamic'
            request.network = networks.first[1]['ip'] # TODO make sure 'ip' is the right field
          end

          response = client.call(request)
          response.handle
        end

        # Chown /var/vcap from root to vcap
        with_warden do |client|
          request = Warden::Protocol::RunRequest.new
          request.handle = handle
          request.privileged = true
          request.script = "chown -R vcap:vcap /var/vcap"

          client.call(request)
        end

        # Agent settings
        env = generate_agent_env(vm, agent_id, networks)

        tempfile = Tempfile.new('settings')
        tempfile.write(Yajl::Encoder.encode(env)) # TODO make sure env is the right setting
        tempfile.close

        with_warden do |client|
          request = Warden::Protocol::CopyInRequest.new
          request.handle = handle
          request.src_path = tempfile.path
          request.dst_path = agent_settings_file

          client.call(request)
        end

        # Notice: It's a little hacky, but it's the way it is now.
        #
        # Warden has a default white list for devices. By default, all the loop
        # devices cannot be read/written/mknod. We don't want to change the
        # warden behavior, so we just manipulate the container cgroup directly.
        sudo "bash -c 'echo \"b 7:* rwm\" > /sys/fs/cgroup/devices/instance-#{handle}/devices.allow'"

        # TODO start agent and other init scripts, something like power on
        with_warden do |client|
          # TODO to be implemented
        end

        # Save to DB
        vm.container_id = handle
        vm.save

        vm.id.to_s
      end
    rescue => e
      # TODO how to clean up
      cloud_error(e)
    end

    ##
    # Deletes a VM
    #
    # @param [String] vm_id vm id
    def delete_vm(vm_id)
      with_thread_name("delete_vm(#{vm_id})") do
        vm = Models::VM[vm_id.to_i]
        raise "VM #{vm} not found" unless vm

        raise "Cannot delete vm with disks attached" if vm.disks.size > 0

        with_warden do |client|
          request = Warden::Protocol::DestroyRequest.new
          request.handle = vm.container_id

          client.call(request)
        end

        Models::VM[vm_id.to_i].delete
      end

    rescue => e
      cloud_error(e)
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

      disk = nil
      image_file = nil

      raise ArgumentError, "disk size <= 0" unless size > 0

      with_thread_name("create_disk(#{size}, _)") do
        disk = Models::Disk.create

        image_file = image_path(disk.id)

        FileUtils.touch(image_file)
        File.truncate(image_file, size << 20) # 1 MB == 1<<20 Byte
        sh "mkfs -t #{@fs_type} -F #{image_file} 2>&1"

        disk.image_path = image_file
        disk.attached = false
        disk.save

        disk.id.to_s
      end
    rescue => e
      FileUtils.rm_f image_file if image_file rescue nil
      disk.destroy if disk rescue nil

      cloud_error(e)
    end

    ##
    # Delete a disk
    #
    # @param [String] disk id
    # @return [void]
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        disk = Models::Disk[disk_id.to_i]

        raise "Cannot find disk #{disk_id}" unless disk
        raise "Cannot delete attached disk" if disk.attached

        disk.destroy

        image_file = image_path(disk_id)
        FileUtils.rm image_file

        nil
      end
    rescue => e
      cloud_error(e)
    end

    ##
    # Attach a disk to a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def attach_disk(vm_id, disk_id)
      with_thread_name("attach_disk(#{vm_id}, #{disk_id})") do
        vm = Models::VM[vm_id.to_i]
        disk = Models::Disk[disk_id.to_i]

        raise "Cannot find vm #{vm_id}" unless vm
        raise "Cannot find disk #{disk_id}" unless disk
        raise "disk #{disk_id} already attached" if disk.attached

        # Get a device number from the pool
        number = @pool.acquire
        raise "Failed to fetch device number" unless number

        # Attach image file to the device
        sudo "losetup /dev/loop#{number} #{disk.image_path}"

        # Create a device file inside warden container
        script = attach_script(number, @device_path_prefix)

        device_path = with_warden do |client|
          request = Warden::Protocol::RunRequest.new
          request.handle = vm.container_id
          request.script = script
          request.privileged = true # TODO or false

          response = client.call(request)

          stdout = response.stdout || ""
          stdout.strip
        end

        # Save DB entry
        disk.device_path = device_path
        disk.device_num = number
        disk.attached = true
        disk.vm = vm
        disk.save

        nil
      end
    rescue => e
      cloud_error(e)
    end

    ##
    # Detach a disk from a VM
    #
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [String] disk disk id that was once returned by {#create_disk}
    # @return nil
    def detach_disk(vm_id, disk_id)
      with_thread_name("detach_disk(#{vm_id}, #{disk_id})") do
        vm = Models::VM[vm_id.to_i]
        disk = Models::Disk[disk_id.to_i]

        raise "Cannot find vm #{vm_id}" unless vm
        raise "Cannot find disk #{disk_id}" unless disk
        raise "disk #{disk_id} not attached" unless disk.attached

        device_num = disk.device_num
        device_path = disk.device_path

        # Save DB entry
        disk.attached = false
        disk.device_num = 0
        disk.device_path = nil
        disk.vm = nil
        disk.save

        # Detach image file from loop device
        sudo "losetup -d /dev/loop#{device_num}"

        # Release the device number back to pool
        @pool.release(device_num)

        # Remove the device file inside warden container
        script = "rm #{device_path}"

        with_warden do |client|
          request = Warden::Protocol::RunRequest.new
          request.handle = vm.container_id
          request.script = script
          request.privileged = true # TODO or false

          client.call(request)
        end

        nil
      end
    rescue => e
      cloud_error(e)
    end

    def validate_deployment(old_manifest, new_manifest)
      # no-op
    end

    private

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
      @warden_unix_path = @warden_properties["unix_domain_path"] || DEFAULT_WARDEN_SOCK
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties["root"] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

    def setup_disk
      @disk_root = @disk_properties["root"] || DEFAULT_DISK_ROOT
      @fs_type = @disk_properties["fs"] || DEFAULT_FS_TYPE
      @pool_size = @disk_properties["pool_count"] || DEFAULT_POOL_SIZE
      @pool_start_number = @disk_properties["pool_start_number"] || DEFAULT_POOL_START_NUMBER
      @device_path_prefix = @disk_properties["device_path_prefix"] || DEFAULT_DEVICE_PREFIX
    end

    def setup_pool
      @pool = DevicePool.new(@pool_size) { |i| i + @pool_start_number }

      occupied_numbers = Models::Disk.collect { |disk| disk.device_num }
      @pool.delete_if do |i|
        occupied_numbers.include? i
      end

      # Initialize the loop devices
      last = @pool_start_number + @pool_size - 1
      @pool_start_number.upto(last) do |i|
        sudo "mknod /dev/loop#{i} b 7 #{i}" unless File.exists? "/dev/loop#{i}"
      end
    end

    def with_warden
      # TODO make sure client is running as root inside container
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

    def generate_agent_env(vm, agent_id, networks)
      vm_env = {
        "name" => vm.container_id,
        "id" => vm.id
      }

      env = {
        "vm" => vm_env,
        "agent_id" => agent_id,
        "networks" => networks,
      }
      env
    end

  end
end
