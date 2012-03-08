

module Bosh::Agent
  class Platform::Ubuntu::Disk

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

    def mount_persistent_disk(cid)
      FileUtils.mkdir_p(store_path)
      disk = Bosh::Agent::Config.infrastructure.lookup_disk_by_cid(cid)
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

    def mount_entry(partition)
      File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
    end

  end
end
