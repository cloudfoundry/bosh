require 'bosh/dev'

module Bosh::Dev::Sandbox
  class RedisWaiter
    def initialize(host, port, logger)
      @host = host
      @port = port
      @logger = logger
    end

    def wait
      tries = 0
      while true
        tries += 1
        begin
          Redis.new(:host => "localhost", :port => @port).info
          break
        rescue Errno::ECONNREFUSED => e
          raise e if tries >= 20
          sleep(0.1)
        end
      end
    end
  end
end
