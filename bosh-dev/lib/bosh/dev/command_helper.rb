require 'open3'

module Bosh::Dev
  module CommandHelper
    def exec_cmd(cmd)
      @logger.info("Executing: #{cmd}")
      Open3.capture3(cmd)
    end
  end
end
