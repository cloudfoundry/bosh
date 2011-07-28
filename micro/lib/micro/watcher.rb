module VCAP
  module Micro
    class Watcher
      attr_reader :sleep

      DEFAULT_SLEEP = 15
      MAX_SLEEP = DEFAULT_SLEEP * 6 # 5 consecutive failures (must not be less than TTL)
      REFRESH_INTERVAL = 14400
      TTL = 60
      A_ROOT_SERVER = '198.41.0.4'
      CLOUDFOUNDRY_COM = 'cloudfoundry.com'
      CLOUDFOUNDRY_IP = '173.243.49.35'

      def initialize(network, identity)
        @network = network
        @identity = identity
        @sleep = DEFAULT_SLEEP
        @start = Time.now.to_i
        @logger = Console.logger
      end

      def start
        @thread = Thread.new do
          @logger.info("watcher thread running...")
          watch
        end
      end

      def watch
        while @sleep < MAX_SLEEP
          check
          @logger.debug("sleeping for #{@sleep} seconds...")
          Kernel.sleep(@sleep)
        end
        @logger.warn("sleep (#{@sleep}) > MAX_SLEEP (#{MAX_SLEEP})")
        $stderr.puts "WARNING: network problem"
        @network.connection_lost
      rescue => e
        @logger.error("watcher caught: #{e.message}\n#{e.backtrace.join("\n")}")
        $stderr.puts "network watcher thread caught: #{e.message}"
        retry
      end

      def check
        if @network.up?
          @logger.debug("network is up")
          ip = VCAP::Micro::Network.local_ip
          gw = VCAP::Micro::Network.gateway

          # if we don't have a gateway something is wrong, increase the sleep
          # time and try again
          unless gw
            @sleep += DEFAULT_SLEEP
            return
          end

          # if we can't ping the local gateway or the DNS A server,
          # then something is wrong
          unless VCAP::Micro::Network.ping(gw)
            @logger.warn("watcher could not ping gateway: #{gw}")
            @network.connection_lost
            return
          else
            @logger.debug("watcher could ping gateway: #{gw}")
          end

          # this might be blocked by firewalls
          #
          # unless VCAP::Micro::Network.ping(A_ROOT_SERVER)
          #   @logger.warn("watcher could not ping external IP: #{A_ROOT_SERVER}")
          #   @network.connection_lost
          #   return
          # else
          #   @logger.debug("watcher could ping external IP: #{A_ROOT_SERVER}")
          # end

          unless VCAP::Micro::Network.lookup(CLOUDFOUNDRY_COM) == CLOUDFOUNDRY_IP
            @logger.warn("watcher could not look up #{CLOUDFOUNDRY_COM}")
            @network.connection_lost
            return
          else
            @logger.debug("watcher could look up #{CLOUDFOUNDRY_COM}")
          end

          # finally check if the actual IP matches the configured IP, and update
          # the DNS record if not
          if @identity.ip && ip != @identity.ip
            # TODO use progress bar
            @logger.info("updating DNS for #{@identity.subdomain} from #{@identity.ip} to #{ip}")
            $stderr.puts "\nupdating DNS for #{@identity.subdomain} from #{@identity.ip} to #{ip}..."
            @identity.update_ip(ip)
            @sleep = TTL # don't run again until the DNS has been updated
            return
          else
            @logger.debug("configured and actual IPs match")
          end

          # refresh DNS record
          if Time.now.to_i - @start > REFRESH_INTERVAL
            @logger.info("refreshing DNS record for #{ip}")
            begin
              @identity.update_ip(ip)
            rescue RestClient::Forbidden
              # do nothing
            end
            @start = Time.now.to_i
          else
            @logger.debug("not time to refresh DNS yet")
          end

          # reset sleep interval if everything worked
          @sleep = DEFAULT_SLEEP
          @logger.info("watcher sucessfully checked network")
        else
          @network.reset unless @network.starting?
        end
      end

    end
  end
end
