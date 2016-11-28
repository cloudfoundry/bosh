require 'open3'

module Bosh::Dev
  module CommandHelper
    def exec_cmd(cmd, dir = Dir.pwd)
      @logger.info("Executing: #{cmd}")
      Open3.capture3(cmd, chdir: dir)
    end
  end
end
