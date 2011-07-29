require 'highline/import'
require 'progressbar'
require 'logger'

require 'micro/network'
require 'micro/identity'
require 'micro/agent'
require 'micro/settings'
require 'micro/watcher'
require 'micro/version'


module VCAP
  module Micro
    class Console

      def self.run
        Console.new.console
      end

      def self.logger
        FileUtils.mkdir_p("/var/vcap/sys/log/micro")
        unless defined? @@logger
          @@logger = Logger.new("/var/vcap/sys/log/micro/micro.log", 5, 1024*100)
          @@logger.level = Logger::INFO
        end
        @@logger
      end

      def initialize
        @identity = Identity.new
        @network = Network.new
        @logger = Console.logger
      end

      def console
        @watcher = Watcher.new(@network, @identity).start
        VCAP::Micro::Agent.start if @identity.configured?
        while true
          clear

          say("Welcome to VMware Micro Cloud Foundry version #{VCAP::Micro::VERSION}\n\n")

          status

          menu
        end
      rescue Interrupt
        puts "\nexiting..."
      rescue => e
        clear
        say("Caught exeption: #{e.message}\n\n")
        # should we only display the first 15 so it won't scroll off the screen?
        say(e.backtrace.join("\n"))
        # retry instead of restart?
        say("\npress any key to restart the console")
        STDIN.getc
      end

      def status
        say("Network: #{@network.status}")
        if @identity.configured? && @network.status == :up
          say("Micro Cloud Foundry operational, to access use:")
          say("vmc target http://api.#{@identity.subdomain}\n\n")
        elsif @identity.configured?
          say("\n")
          say("vmc target http://api.#{@identity.subdomain}\n\n")
        else
          say("DNS not configured\n\n")
        end
      end

      def menu
        choose do |menu|
          menu.select_by = :index
          menu.prompt = "Select option: "
          unless @identity.configured?
            menu.choice("configure") { configure }
            menu.choice("refresh console") { }
          else
            menu.choice("refresh console") { }
            menu.choice("refresh DNS") { refresh_dns }
            menu.choice("reconfigure vcap password") { configure_password }
            menu.choice("reconfigure domain") { configure_domain }
            menu.choice("reconfigure network [#{@network.type}]") { configure_network }
            menu.choice("reconfigure proxy [#{@identity.proxy}]") { configure_proxy }
            menu.choice("service status") { service_status }
            menu.choice("restart network") { restart }
            menu.choice("restore defaults") { defaults }
          end
          menu.choice("help") { display_help }
          menu.choice("shutdown VM") { shutdown }
          menu.hidden("debug") { @logger.level = Logger::DEBUG }
        end
      end

      def configure
        configure_password
        configure_domain
        configure_network # should this go before nonce in case it changes the network?
        configure_proxy
        say("\nInstalling Micro Cloud Foundry...\n\n")
        # TODO use a progres bar
        VCAP::Micro::Agent.apply(@identity)
      end

      def configure_password
        pass = ask("\nSet Micro Cloud Foundry VM user password:  ") { |q| q.echo = "*" }
        # BIG HACK
        `echo "root:#{pass}\nvcap:#{pass}" | chpasswd`
      end

      def configure_domain
        @identity.clear
        token = ask("\nEnter Micro Cloud Foundry configuration token (or vcap.me for local DNS):")
        if token == ""
          return
        elsif token == "vcap.me"
          @identity.vcap_me
        else
          @identity.nonce = token
          @identity.install(VCAP::Micro::Network.local_ip)
        end
        @identity.save
      rescue SocketError
        @identity.vcap_me
        @identity.save
      rescue RestClient::ResourceNotFound, RestClient::Forbidden, RestClient::Conflict
        say("Leave blank to return to menu")
        retry
      end

      def configure_network
        say("\n")
        choose do |menu|
          menu.prompt = "Select network: "
          menu.choice("DHCP") do
            @network.dhcp
          end
          menu.choice("Static") do
            net = Hash.new
            say("\nEnter network configuration (address/netmask/gateway/DNS)")

            net['address'] = ask("Address: ")
            net['netmask'] = ask("Netmask: ")
            net['gateway'] = ask("Gateway: ")
            net['dns'] =     ask("DNS:     ")
            # TODO validate network
            @network.static(net)
          end
        end
      end

      def configure_proxy
        # TODO validate proxy string
        # TODO if we set a proxy after the initial config, the cloud
        # controller needs to be updated and restarted
        proxy = ask("\nHTTP proxy: ") { |q| q.default = "none" }
        @identity.proxy = proxy if proxy != "none"
      end

      def refresh_dns
        ip = Network.local_ip
        @identity.update_ip(ip) # spin off in a thread?
        pbar = ProgressBar.new("updating", Watcher::TTL)
        i = 1
        while i <= Watcher::TTL
          # break if vcap.me
          break if Network.lookup(@identity.subdomain) == ip
          pbar.inc
          sleep(1)
          i += 1
        end
        pbar.finish
        sleep 3 # give it a few seconds to display the finished state
        # TODO error message if it doesn't match after TTL seconds
      end

      def restart
        @network.reset
      end

      def service_status
        clear
        say("Service status:\n")
        status = Bosh::Agent::Monit.retry_monit_request do |client|
          client.status(:group => Bosh::Agent::BOSH_APP_GROUP)
        end
        status.each do |name, data|
          if data[:monitor] == :yes
            printf("%-25s: %s\n", name, data[:status][:message])
          end
        end
        ask("\nPress return to continue")
      end

      def defaults
        @identity.clear
        @network.dhcp
        # what about the agent?
        # what about the vcap password?
      end

      def display_help
        clear
        File.open("/var/vcap/micro/banner") do |file|
          file.readlines.each { |line| puts line }
        end

        ask("Press return to continue")
      end

      def shutdown
        # perhaps get confirmation?
        clear
        say("shutting down VM...")
        # TODO issue monit stop all
        `poweroff`
        sleep 3600 # until the cows come home
      end

      def clear
        print "\e[H\e[2J"
      end
    end
  end
end

if $0 == __FILE__
  VCAP::Micro::Console.run
end

