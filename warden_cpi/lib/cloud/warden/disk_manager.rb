
module Bosh::WardenCloud

  class DiskManager

    def initialize(disk_dir, device_pool)
      @disk_dir = disk_dir
      @device_pool = device_pool
      @script_dir = File.expand_path("../../../../root", __FILE__)

      create_disk_dir()
    end

    def create_disk(size)
      if size <= 0
        raise ArgumentError, "Size must be > 0 when creating disk"
      end

      unless have_enough_space?(size)
        raise Bosh::Clouds::NoDiskSpace, false
      end

      disk_id = SecureRandom.uuid
      disk_path = disk_path(disk_id)
      device_num = @device_pool.acquire
      device_path = device_path(device_num)

      FileUtils.touch(disk_path)
      File.truncate(disk_path, size * 1024 * 1024)

      begin
        sh("sudo #{script("create_disk.sh")} #{disk_path} #{device_path} #{device_num}")
      rescue
        @device_pool.release(device_num)
        FileUtils.rm_f(disk_path)
        raise
      end

      Disk.new(disk_id, device_num)
    end

    def delete_disk(disk)
      disk_path = disk_path(disk.uuid)
      device_path = device_path(disk.device_num)
      sh("sudo #{script("delete_disk.sh")} #{device_path}")
      @device_pool.release(disk.uuid)
      FileUtils.rm_f(disk_path)
    end

    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def detach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    private

    def sh(cmd)
      Bosh::Exec.sh(cmd + " > /dev/null 2>&1")
    end

    def script(file)
      File.join(@script_dir, file)
    end

    def disk_path(uuid)
      File.join(@disk_dir, uuid)
    end

    def device_path(device_num)
      "/dev/loop#{device_num}"
    end

    def have_enough_space?(size)
      stat = Sys::Filesystem.stat(@disk_dir)
      size < stat.block_size * stat.blocks_available / 1024 / 1024
    end

    def create_disk_dir
      FileUtils.mkdir_p(@disk_dir)
    end
  end
end
