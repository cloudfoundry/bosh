
module Bosh::WardenCloud

  class DevicePool

    def initialize(pool)
      @pool = pool
    end

    def acquire
      device = @pool.delete_at(0)
      unless device
        Bosh::Clouds::Config.logger.debug("Can't acquire device")
        raise Bosh::Clouds::CloudError.new
      end
      device
    end

    def release(device)
      @pool.push(device)
    end
  end

  class DiskManager

    def initialize(options)
      @options = options || {}
      @device_pool = setup_device_pool
    end

    ##
    # Creates a new disk image
    # @param [Integer] size disk size in MiB
    # @raise [Bosh::Clouds::NoDiskSpace] if system has not enough free space
    # @raise [Bosh::Clouds::CloudError] when meeting internal error
    # @return [String] disk id
    def create_disk(size)
      logger.debug("Entering create_disk, size = #{size}")

      return nil unless size > 0
      raise Bosh::Clouds::NoDiskSpace.new(false) unless have_enough_free_space?(size)

      create_disk_dir unless File.exist?(disk_dir)
      create_disk_image(size)
    end

    def delete_disk(disk_id)
      # TODO to be implemented
    end

    ##
    # Attach a disk image to a warden container
    # @param [String] container_id warden container handle
    # @param [String] disk_id disk id
    # @return nil
    def attach_disk(container_id, disk_id)
      logger.debug("Entering attach_disk, container_id = #{container_id}, disk_id = #{disk_id}")

      raise Bosh::Clouds::DiskNotFound.new(false) unless disk_exists?(disk_id)
      raise Bosh::Clouds::VMNotFound.new unless container_exists?(container_id)

      logger.info("Start to attach #{disk_id} to #{container_id}")
      device_path, device_num = attach_disk_image(container_id, disk_id)

      begin
        store_attach_info(container_id, disk_id, device_path, device_num)
      rescue
        delete_disk_image(container_id, device_path, device_num)
        raise
      end

      begin
        register_disk_in_agent(container_id, disk_id, device_path)
      rescue
        delete_disk_image(container_id, device_path, device_num)
        delete_attach_info(disk_id)
        raise
      end
    end

    def detach_disk(container_id, disk_id)
      # TODO to be implemented
    end

    private

    def register_disk_in_agent(container_id, disk_id, device_path)
      # to be done
    end

    def store_attach_info(container_id, disk_id, device_path, device_num)
      # to be done
    end

    def delete_attach_info(disk_id)
      # to be done
    end

    def create_device_host(device_num)
      file = "/dev/loop#{device_num}"
      return file if File.exists?(file)
      raise Bosh::Clouds::CloudError.new if exec_sh("mknod #{file} b 7 #{device_num}").failed?
      file
    end

    def run_cmd_in_container(container_id, cmd)
      # to be done, return the status
      0
    end

    def get_available_device_in_container(container_id)
      “bcedfghigklmnopqrstuvwxyz”.each_char do |c|
        device = "/dev/sd#{c}"
        status = run_cmd_in_container(container_id, "ls #{device}")
        return device if status == 0
      end
      raise Bosh::Clouds::CloudError.new
    end

    def create_device_in_container(container_id, device_num)
      device = get_available_device_in_container(container_id)
      cmd = "mknod #{device} b 7 #{device_num}"
      status = run_cmd_in_container(container_id, cmd)
      raise Bosh::Clouds::CloudError.new if status != 0
    def

    def delete_device_in_container(container_id, device_path)
      begin
        run_cmd_in_container(container_id, "umount #{device_path}")
      rescue
        # ignore the error
      end

      run_cmd_in_container(container_id, "rm -f #{device_path}")
    end

    def attach_disk2device(disk_id, host_device)
      result = exec_sh("losetup #{host_device} #{File.join(disk_dir, disk_id}")
      raise Bosh::Clouds::CloudError.new if result.failed?
    end

    def detach_disk_from_device(host_device)
      result = exec_sh("losetup -d #{host_device}")
      raise Bosh::Clouds::CloudError.new if result.failed?
    end

    def attach_disk_image(container_id, disk_id)
      device_num = @device_pool.acquire
      begin
        container_device = create_device_in_container(container_id, device_num)
        host_device = create_device_in_host(device_num)
        attach_disk2device(disk_id, host_device)
      rescue
        @device_pool.release(device_num)
        raise
      end
      container_device, device_num
    end

    def detach_disk_image(container_id, device_path, device_num)
      begin
        delete_device_in_container(container_id, device_path)
        detach_disk_from_device("/dev/loop#{device_num}")
      rescue
        raise
      ensure
        @device_pool.release(device_num)
      end
    end

    def device_occupied?()
      # to be done
    end

    def setup_device_pool
      start = @options["pool_start_num"]
      count = @options["pool_count"]
      pool = []
      count.times do |i|
        device_num = start + i
        pool.push(device_num) unless device_occupied?(device_num)
      end
      pool
    end

    def logger
      Bosh::Clouds::Config.logger
    end

    def warden_client
      # TODO to be implemented
    end

    def disk_dir
      @options["disk_dir"]
    end

    def exec_sh(cmd)
      Bosh::Exec.sh(cmd, :on_error => :return)
    end

    def disk_exists?(disk_id)
      File.exists?(File.join(disk_dir, disk_id))
    end

    def container_exists?(container_id)
      # to be done
    end

    def have_enough_free_space?(size)
      stat = Sys::Filesystem.stat(disk_dir)
      size < stat.block_size * stat.blocks_available / 1024 / 1024
    end

    def create_disk_dir
      logger.info("Disk dir not exists, creating it ...")
      begin
        FileUtils.mkdir_p(disk_dir)
      rescue
        logger.debug("Creating disk dir #{disk_dir} failed")
        raise Bosh::Clouds::CloudError.new
      end
    end

    def generate_disk_uuid
      SecureRandom.uuid
    end

    def create_disk_image(size)

      uuid = generate_disk_uuid
      file = File.join(disk_dir, uuid)

      logger.info("Ready to crate disk image #{uuid} in #{disk_dir}")

      cmd = "dd if=/dev/null of=#{file} bs=1M seek=#{size} > /dev/null 2>&1"
      if exec_sh(cmd).failed?
        logger.debug("Creating disk image #{uuid} failed")
        raise Bosh::Clouds::CloudError.new
      end

      cmd = "mkfs.ext4 -F #{file} > /dev/null 2>&1"
      if exec_sh(cmd).failed?
        FileUtils.rm_f(file)
        logger.debug("Making file system failed")
        raise Bosh::Clouds::CloudError.new
      end

      logger.info("Sucessfully creating disk image #{uuid}")

      uuid
    end
  end
end
