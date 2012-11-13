
module Bosh::WardenCloud

  class DiskManager

    def initialize(options)
      @disk_dir = options["disk_dir"] || "/tmp/disk_images"
    end

    ##
    # Creates a new disk image
    # @param [Integer] size disk size in MiB
    # @param [String] uuid disk uuid
    # @return nil
    def create_disk(size, uuid)
      raise ArgumentError.new, "Size must be > 0 when creating disk" unless size > 0
      raise Bosh::Clouds::NoDiskSpace.new(false) unless have_enough_space?(size)
      create_disk_dir
      create_disk_image(size, uuid)
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

    def warden_client
      # TODO to be implemented
    end

    def disk_path(uuid)
      File.join(@disk_dir, uuid)
    end

    def exec_sh(cmd)
      Bosh::Exec.sh(cmd)
    end

    def have_enough_space?(size)
      stat = Sys::Filesystem.stat(@disk_dir)
      size < stat.block_size * stat.blocks_available / 1024 / 1024
    end

    def create_disk_dir
      FileUtils.mkdir_p(@disk_dir)
    end

    def create_disk_image(size, uuid)
      disk_path = disk_path(uuid)
      exec_sh("dd if=/dev/null of=#{disk_path} bs=1M seek=#{size} > /dev/null 2>&1")

      begin
        exec_sh("mkfs.ext4 -F #{disk_path} > /dev/null 2>&1")
      rescue
        FileUtils.rm_f(disk_path)
        raise
      end
    end
  end
end
