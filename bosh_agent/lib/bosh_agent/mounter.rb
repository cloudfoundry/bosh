require 'bosh_agent'

module Bosh::Agent
  class Mounter
    def initialize(platform, cid, store_path, logger)
      @platform = platform
      @cid = cid
      @store_path = store_path
      @logger = logger
    end

    def mount(options)
      disk = @platform.lookup_disk_by_cid(@cid)
      partition = "#{disk}1"

      @logger.info("Mounting: #{partition} #{@store_path}")
      output = `mount #{options} #{partition} #{@store_path}`

      unless (status = last_process_status.exitstatus).zero?
        raise Bosh::Agent::MessageHandlerError,
          "Failed to mount: '#{partition}' '#{@store_path}' Exit status: #{status} Output: #{output}"
      end
    end

    private

    def last_process_status
      $?
    end
  end
end
