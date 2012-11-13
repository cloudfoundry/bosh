
module Bosh::WardenCloud::Model

  class Disk

    attr_accessor :uuid
    attr_accessor :device_num

    def initialize(uuid, device_num)
      @uuid = uuid
      @device_num = device_num
    end
  end
end
