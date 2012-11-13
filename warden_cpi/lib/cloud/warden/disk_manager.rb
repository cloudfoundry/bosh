
module Bosh::WardenCloud

  class DiskManager

    def initialize(options)
      @options = options || {}
    end

    ##
    # Creates a new disk image
    # @param [Integer] size disk size in MiB
    # @param [String] vm_locality not be used in warden cpi
    # @raise [Bosh::Clouds::NoDiskSpace] if system has not enough free space
    # @raise [Bosh::Clouds::CloudError] when meeting internal error
    # @return [String] disk id
    def create_disk(size)
      logger.debug("Entering create_disk, size == #{size}")
      return nil unless size > 0
      raise Bosh::Clouds::NoDiskSpace.new(false) unless have_enough_free_space?(size)
      create_disk_dir unless File.exist?(disk_dir)
      create_disk_image(size)
    end

    def delete_disk(disk_id)
      # TODO to be implemented
    end

    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def detach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    private

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

    def not_used(var)
      # no-op
    end

  end
end
