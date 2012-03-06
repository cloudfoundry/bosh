module Bosh::Agent
  class Infrastructure::Vsphere::Disk

    def initialize
    end

    def logger
      Bosh::Agent::Config.logger
    end

    def base_dir
      Bosh::Agent::Config.base_dir
    end

    def store_path
      File.join(base_dir, 'store')
    end

    DATA_DISK = "/dev/sdb"
    def setup_data_disk
      swap_partition = "#{DATA_DISK}1"
      data_partition = "#{DATA_DISK}2"

      unless File.blockdev?(DATA_DISK)
        return false
      end

      if Dir["#{DATA_DISK}[1-9]"].empty?
        logger.info("Found unformatted drive")
        logger.info("Partition #{DATA_DISK}")
        Bosh::Agent::Util.partition_disk(DATA_DISK, data_sfdisk_input)

        logger.info("Create swap and data partitions")
        %x[mkswap #{swap_partition}]
        %x[/sbin/mke2fs -t ext4 -j #{data_partition}]
      end

      logger.info("Swapon and mount data partition")
      %x[swapon #{swap_partition}]
      %x[mkdir -p #{base_dir}/data]

      data_mount = "#{base_dir}/data"
      unless Pathname.new(data_mount).mountpoint?
        %x[mount #{data_partition} #{data_mount}]
      end
      true
    end

    def data_sfdisk_input
      ",#{swap_size},S\n,,L\n"
    end

    def swap_size
      disk_size = Bosh::Agent::Util.block_device_size(DATA_DISK)
      if mem_total > disk_size/2
        return (disk_size/2)/1024
      else
        return mem_total/1024
      end
    end

    def mem_total
      # MemTotal:        3952180 kB
      File.readlines('/proc/meminfo').first.split(/\s+/)[1].to_i
    end

    def mount_persistent_disk(cid)
      FileUtils.mkdir_p(store_path)
      disk = lookup_disk_by_cid(cid)
      partition = "#{disk}1"
      if File.blockdev?(partition) && !mount_entry(partition)
        mount(partition, store_path)
      end
    end

    def mount(partition, path)
      logger.info("Mount #{partition} #{path}")
      `mount #{partition} #{path}`
      unless $?.exitstatus == 0
        raise Bosh::Agent::FatalError, "Failed to mount: #{partition} #{path}"
      end
    end

    def lookup_disk_by_cid(cid)
      settings = Bosh::Agent::Config.settings
      disk_id = settings['disks']['persistent'][cid]

      unless disk_id
        raise Bosh::Agent::FatalError, "Unknown persistent disk: #{cid}"
      end
      sys_path = detect_block_device(disk_id)
      blockdev = File.basename(sys_path)
      File.join('/dev', blockdev)
    end

    def detect_block_device(disk_id)
      dev_path = "/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*"
      while Dir[dev_path].empty?
        logger.info("Waiting for #{dev_path}")
        sleep 0.1
      end
      Dir[dev_path].first
    end

    def mount_entry(partition)
      File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
    end

  end
end
