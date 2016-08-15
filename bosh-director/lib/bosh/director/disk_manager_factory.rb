module Bosh::Director
  class DiskManagerFactory
    def initialize(logger)
      @logger = logger
    end

    def new_disk_manager(options={})
      multiple_disks = options.fetch(:multiple_disks, false)
      multiple_disks ? MultipleDisksManager.new(@logger) : SingleDiskManager.new(@logger)
    end
  end
end
