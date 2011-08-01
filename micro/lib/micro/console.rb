require 'highline/import'
require 'progressbar'
require 'logger'

require 'micro/network'
require 'micro/identity'
require 'micro/agent'
require 'micro/settings'
require 'micro/watcher'
require 'micro/version'
require 'micro/core_ext'


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
        # TODO add a timeout so the console will be auto-refreshed
        while true
          clear

          say("              Welcome to VMware Micro Cloud Foundry version #{VCAP::Micro::VERSION}\n\n")

          status

          menu
        end
      rescue Interrupt
        puts "\nrestarting console..."
      rescue => e
        clear
        say("Caught exeption: #{e.message}\n\n")
        # should we only display the first 15 so it won't scroll off the screen?
        say(e.backtrace.join("\n"))
        @logger.error("caught exception: #{e.message}\n#{e.backtrace.join("\n")}")
        # retry instead of restart?
        say("\npress any key to restart the console")
        STDIN.getc
      end

      def status
        stat = @network.status.to_s
        s = case @network.status
          when :up
            stat.green
          when :failed
            stat.red
          else
            stat.yellow
          end

        if @identity.configured?
          say("Current Configuration:")
          say(" Identity:   #{@identity.subdomain}")
          say(" Admin:      #{@identity.admins.join(', ')}")
          say(" IP Address: #{@identity.ip}  (network #{s})\n\n")
          say("To access your Micro Cloud Foundry instance, use:")
          say("vmc target http://api.#{@identity.subdomain}\n\n")
        else
          say("Network #{s}")
          say("Micro Cloud Foundry not configured\n\n")
        end
      end

      def menu
        choose do |menu|
          menu.select_by = :index
          menu.prompt = "\nSelect option: "
          unless @identity.configured?
            menu.choice("configure") { configure }
            menu.choice("refresh console") { }
          else
            menu.choice("refresh console") { }
            menu.choice("refresh DNS") { refresh_dns }
            menu.choice("reconfigure vcap password") { configure_password }
            menu.choice("reconfigure domain") { configure_domain }
            menu.choice("reconfigure network [#{@network.type}]") { configure_network }
            menu.choice("reconfigure proxy [#{@identity.display_proxy}]") { configure_proxy }
            menu.choice("service status [#{service_status}]") { display_services }
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
        password = "foo"
        confirmation = "bar"
        say("\nSet password Micro Cloud Foundry VM user")
        while password != confirmation
          password = ask("Password: ") { |q| q.echo = "*" }
          confirmation = ask("Confirmation: ") { |q| q.echo = "*" }
          say("Passwords do not match!\n".red) unless password == confirmation
        end
        # BIG HACK
        `echo "root:#{password}\nvcap:#{password}" | chpasswd`
        if $? == 0
          say("Password changed!".green)
        else
          say("WARNING: unable to set password!".red)
        end
        sleep 3
      end

      def configure_domain
        @identity.clear
        token = ask("\nEnter Micro Cloud Foundry configuration token: ")
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
        @identity.update_ip(Network.local_ip)
      end

      def restart
        @network.reset
      end

      def display_services
        clear
        say("Service status:\n")
        status = Bosh::Agent::Monit.retry_monit_request do |client|
          client.status(:group => Bosh::Agent::BOSH_APP_GROUP)
        end
        status.each do |name, data|
          if data[:monitor] == :yes
            status = data[:status][:message]
            printf(" %-25s %s\n", name, status == "running" ? status.green : status.red)
          end
        end
        say("\n")
        press_return_to_continue
      end

      def service_status
        status = Bosh::Agent::Monit.retry_monit_request do |client|
          client.status(:group => Bosh::Agent::BOSH_APP_GROUP)
        end
        status.each do |name, data|
          if data[:monitor] == :yes
            return "failed".red if data[:status][:message] != "running"
          end
        end
        "ok".green
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

        press_return_to_continue
      end

      def shutdown
        return unless ask("Really shut down VM? ").match(/^y(es)*$/i)
        clear
        say("Stopping Cloud Foundry services...")
        Bosh::Agent::Monit.stop_services
        sleep 5 # TODO loop and wait until all are stopped
        say("shutting down VM...")
        `poweroff`
        sleep 3600 # until the cows come home
      end

      def clear
        print "\e[H\e[2J"
      end
      def press_return_to_continue
        ask("Press return to continue ")
      end
    end
  end
end

if $0 == __FILE__
  VCAP::Micro::Console.run
end

