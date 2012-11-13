
module Bosh::WardenCloud

  class DiskManager

    include Bosh::Exec

    def initialize(options)
      @disk_dir = options["disk_dir"] || "/tmp/disk_images"

      create_disk_dir()
    end

    def create_disk(disk, size)
      if size <= 0
        raise ArgumentError.new, "Size must be > 0 when creating disk"
      end

      unless have_enough_space?(size)
        raise Bosh::Clouds::NoDiskSpace.new(false)
      end

      disk_path = disk_path(disk.uuid)
      device_path = device_path(disk.device_num)

      sh("dd if=/dev/null of=#{disk_path} bs=1M seek=#{size} > /dev/null 2>&1")
      sh("mkfs.ext4 -F #{disk_path} > /dev/null 2>&1")
      unless File.exist?(device_path)
        sh("mknod #{device_path} b 7 #{disk.device_num} > /dev/null 2>&1")
      end
      sh("losetup #{device_path} #{disk_path} > /dev/null 2>&1")
    rescue
      FileUtils.rm_f(disk_path)
      FileUtils.rm_f(device_path)
      raise
    end

    def delete_disk(disk)
      disk_path = disk_path(disk.uuid)
      device_path = device_path(disk.device_num)
      sh("losetup -d #{device_path} > /dev/null 2>&1")
      File.rm_f(device_path)
      File.rm_f(disk_path)
    end

    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def detach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    private

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
