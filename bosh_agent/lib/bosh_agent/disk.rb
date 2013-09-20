module Bosh::Agent
  class Disk
    def initialize(device_path)
      @device_path = device_path
    end

    def partition_path
      "#{@device_path}1"
    end

    def mount(store_path, options)
      `mount #{options} #{partition_path} #{store_path}`
      $?.exitstatus == 0
    end
  end
end
