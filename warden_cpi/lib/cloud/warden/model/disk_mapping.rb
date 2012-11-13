
module Bosh::WardenCloud::Model

  class DiskMapping

    attr_accessor :disk_id
    attr_accessor :container_id
    attr_accessor :device_path

    def initialize(disk_id, container_id, device_path)
      @disk_id = disk_id
      @container_id = container_id
      @device_path = device_path
    end
  end
end
