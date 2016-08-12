module Bosh::Director
  class DiskManagerFactory
    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
    end

    def new_disk_manager(options={})
      multiple_disks = options.fetch(:multiple_disks, false)
      multiple_disks ? MultipleDisksManager.new(@cloud, @logger) : SingleDiskManager.new(@cloud, @logger)
    end
  end
end
