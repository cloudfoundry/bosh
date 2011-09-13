module VCAP
  module Micro
    class Watcher
      attr_reader :sleep, :paused

      PING_SLEEP = 5
      DEFAULT_SLEEP = 15
      MAX_SLEEP = DEFAULT_SLEEP * 6 # 5 consecutive failures (must not be less than TTL)
      REFRESH_INTERVAL = 14400
      TTL = 60
      A_ROOT_SERVER_IP = '198.41.0.4'
      A_ROOT_SERVER = 'a.root-servers.net'

      def initialize(network, identity)
        @network = network
        @identity = identity
        @sleep = DEFAULT_SLEEP
        @paused = false
        @start = Time.now.to_i
        @logger = Console.logger
      end

      def start
        @thread = Thread.new do
          @logger.info("watcher thread running...")
          watch
        end
      end

      def pause
        @paused = true
        # reset sleep when we pause so it will be responsive when we resume
        @sleep = DEFAULT_SLEEP
      end

      def resume
        @paused = false
      end

      def watch
        while true
          check unless @paused
          @logger.debug("sleeping for #{@sleep} seconds...")
          Kernel.sleep(@sleep)
        end
      rescue => e
        @logger.error("watcher caught: #{e.message}\n#{e.backtrace.join("\n")}")
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
            @sleep = MAX_SLEEP if @sleep > MAX_SLEEP
            return
          end

          # if we can't ping the local gateway then something is wrong
          unless forgiving_ping(gw)
            @logger.warn("watcher could not ping gateway: #{gw}")
            # some networks, like the free WiFi at McCarren, actually
            # block ping to the gateway (why on earth are they doing that,
            # it is NOT improving the security) so we can't count on it
            # being a valid test - so just log the result
          else
            @logger.debug("watcher could ping gateway: #{gw}")
          end

          # TODO investigate why this sometimes fail when it works from
          # the OS (host s.root-servers.net)
          unless VCAP::Micro::Network.lookup(A_ROOT_SERVER) == A_ROOT_SERVER_IP
            @logger.warn("watcher could not look up #{A_ROOT_SERVER}")
            @network.connection_lost
            return
          else
            @logger.debug("watcher could look up #{A_ROOT_SERVER}")
          end

          # finally check if the actual IP matches the configured IP, and update
          # the DNS record if not
          if @identity.ip && ip != @identity.ip
            @logger.info("updating DNS for #{@identity.subdomain} from #{@identity.ip} to #{ip}")
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
              # don't litter the console with dns update info
              @identity.update_ip(ip, true)
            rescue RestClient::Forbidden
              # do nothing
            end
            @start = Time.now.to_i
          else
            @logger.debug("not time to refresh DNS yet")
          end

          # reset sleep interval if everything worked
          @sleep = DEFAULT_SLEEP
          @logger.debug("watcher sucessfully checked network")
        else
          @logger.debug("network down")
          unless @network.starting?
            @logger.debug("restarting network")
            @network.restart
          end
        end
      end

      # perhaps we should auto-adjust the number of tries if we detect
      # network flapping?
      def forgiving_ping(host, tries=3)
        count = 0
        while true
          return true if VCAP::Micro::Network.ping(host)
          count += 1
          @logger.debug("ping failed: #{count} of #{tries}")
          return false if count == tries
          Kernel.sleep(PING_SLEEP)
        end
      end

    end
  end
end
