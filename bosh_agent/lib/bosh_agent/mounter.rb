require 'bosh_agent'

module Bosh::Agent
  class Mounter
    def initialize(platform, cid, store_path, logger, backticker)
      @platform = platform
      @cid = cid
      @store_path = store_path
      @logger = logger
      @backticker = backticker
    end

    def mount(options)
      disk = @platform.lookup_disk_by_cid(@cid)
      partition = "#{disk}1"
      @logger.info("Mounting: #{partition} #{@store_path}")
      @backticker.send(:`, "mount #{options} #{partition} #{@store_path}")
      unless $?.exitstatus == 0
        raise Bosh::Agent::MessageHandlerError, "Failed to mount: #{partition} #{@store_path} (exit code #{$?.exitstatus})"
      end
    end
  end
end
