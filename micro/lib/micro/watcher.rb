module VCAP
  module Micro
    class Watcher
      attr_reader :sleep

      DEFAULT_SLEEP = 5
      MAX_SLEEP = 30 # 5 + 5*5, i.e. 5 consecutive failures
      A_ROOT_SERVER = '198.41.0.4'
      CLOUDFOUNDRY_COM = 'cloudfoundry.com'
      CLOUDFOUNDRY_IP = '173.243.49.35'

      def initialize(network, identity)
        @network = network
        @identity = identity
        @sleep = DEFAULT_SLEEP
      end

      def watch
        @thread ||= Thread.new do
          while @sleep < MAX_SLEEP
            check
            sleep @sleep
          end
          $stderr.puts "WARNING: network problem"
        end
      rescue => e
        $stderr.puts "network watcher thread caught: #{e.message}"
        retry
      end

      def check
        if @network.up?
          ip = VCAP::Micro::Network.local_ip
          gw = VCAP::Micro::Network.gateway

          # if we don't have a gateway something is wrong, increase the sleep
          # time and try again
          unless gw
            @sleep += DEFAULT_SLEEP
            return
          end

          # if we can't ping the local gateway or google's public DNS server,
          # then something is wrong
          unless VCAP::Micro::Network.ping(gw) && VCAP::Micro::Network.ping(A_ROOT_SERVER)
            @network.restart
            return
          end

          unless VCAP::Micro::Network.lookup(CLOUDFOUNDRY_COM) == CLOUDFOUNDRY_IP
            @network.restart
            return
          end

          # finally check if the actual IP matches the configured IP, and update
          # the DNS record if not
          unless ip == @identity.ip
            $stderr.puts "\nupdating from #{@identity.ip} to #{ip}..."
            @identity.update_ip(ip)
          end

          # reset sleep interval if everything worked
          @sleep = DEFAULT_SLEEP
        end
      end

    end
  end
end
