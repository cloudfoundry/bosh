
module Bosh::WardenCloud

  class DevicePool

    def initialize(array)
      @pool = array
    end

    def acquire
      device_num = @pool.delete_at(0)
      unless device_num
        raise Bosh::Clouds::CloudError, "No available device"
      end
      device_num
    end

    def release(device_num)
      @pool.push(device_num)
    end
  end
end
