module Bosh::WardenCloud
  class DiskUtils

    include Bosh::WardenCloud::Helpers

    UMOUNT_GUARD_RETRIES = 60
    UMOUNT_GUARD_SLEEP = 3

    def initialize(disk_root, stemcell_root, fs_type)
      @disk_root = disk_root
      @fs_type = fs_type
      @stemcell_root = stemcell_root

      unless Dir.exist?(disk_root)
        FileUtils.mkdir_p(disk_root)
      end
    end

    def create_disk(disk_id, size)
      raise ArgumentError, 'disk size <= 0' unless size > 0

      image_file = image_path(disk_id)
      FileUtils.touch(image_file)
      File.truncate(image_file, size << 20) # 1 MB == 1<<20 Byte
      sh "/sbin/mkfs -t #{@fs_type} -F #{image_file} 2>&1"

    rescue => e
      if image_file
        FileUtils.rm_f image_file if File.exist?(image_file)
      end
      raise e
    end

    def delete_disk(disk_id)
      FileUtils.rm_f image_path(disk_id)
    end

    def disk_exist?(disk_id)
      File.exist?(image_path(disk_id))
    end

    def mount_disk(path, disk_id)
      unless Dir.exist?(path)
        FileUtils.mkdir_p(path)
      end

      disk_img = image_path(disk_id)
      sudo "mount #{disk_img} #{path} -o loop"
    end

    def umount_disk(path)
      umount_guard path
    end

    def stemcell_unpack(image_path, stemcell_id)
      stemcell_dir = stemcell_path(stemcell_id)
      unless Dir.exist?(stemcell_dir)
        FileUtils.mkdir_p(stemcell_dir)
      end
      raise "#{image_path} not exist for creating stemcell" unless File.exist?(image_path)
      sudo "tar -C #{stemcell_dir} -xzf #{image_path} 2>&1"
    rescue => e
      sudo "rm -rf #{stemcell_dir}"
      raise e
    end

    def stemcell_delete(stemcell_id)
      stemcell_dir = stemcell_path(stemcell_id)
      sudo "rm -rf #{stemcell_dir}"
    end

    def image_path(disk_id)
      File.join(@disk_root, "#{disk_id}.img")
    end

    def stemcell_path(stemcell_id)
      File.join(@stemcell_root, stemcell_id)
    end

    private

    def mount_entry(partition)
      `mount`.lines.select { |l| l.match(/#{partition}/) }.first
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

  end

end