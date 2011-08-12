require 'highline/import'
require 'progressbar'
require 'logger'

require 'micro/network'
require 'micro/identity'
require 'micro/agent'
require 'micro/settings'
require 'micro/watcher'
require 'micro/version'
require 'micro/memory'
require 'micro/proxy'
require 'micro/core_ext'


module VCAP
  module Micro
    class Console

      def self.run
        Console.new.console
      end

      LOGFILE = "/var/vcap/sys/log/micro/micro.log"
      def self.logger
        FileUtils.mkdir_p(File.dirname(LOGFILE))
        unless defined? @@logger
          @@logger = Logger.new(LOGFILE, 5, 1024*100)
          @@logger.level = Logger::INFO
        end
        @@logger
      end

      def initialize
        @logger = Console.logger
        @proxy = Proxy.new
        @identity = Identity.new(@proxy)
        @network = Network.new
        @memory = Memory.new
        @watcher = Watcher.new(@network, @identity).start
      end

      def console
        VCAP::Micro::Agent.start if @identity.configured?
        # TODO add a timeout so the console will be auto-refreshed
        while true
          clear
          say("              Welcome to VMware Micro Cloud Foundry version #{VCAP::Micro::VERSION}\n\n")
          status
          menu
        end
      rescue Interrupt
        retry unless are_you_sure?("\nAre you sure you want to restart the console?")
        puts "\nrestarting console..."
      rescue => e
        clear
        @logger.error("caught exception: #{e.message}\n#{e.backtrace.join("\n")}")
        say("Oh no, an uncaught exception: #{e.message}\n\n")
        say(e.backtrace.first(15).join("\n")) if @logger.level == Logger::DEBUG
        # retry instead of restart?
        say("\npress any key to restart the console")
        STDIN.getc
      end

      def status
        if @identity.api_host != Identity::DEFAULT_API_HOST
          say("Using API host: #{@identity.api_host}\n".yellow)
        end
        if @identity.should_update?
          url = "http://cloudfoundry.com/micro"
          say("A new version is available for download at #{url}\n".yellow)
        end
        if @identity.configured?
          say("Current Configuration:")
          say(" Identity:   #{@identity.subdomain} (#{dns_status})")
          say(" Admin:      #{@identity.admins.join(', ')}")
          say(" IP Address: #{@identity.ip} (network #{network_status})\n\n")
          say("To access your Micro Cloud Foundry instance, use:")
          say("vmc target http://api.#{@identity.subdomain}\n\n")
        else
          say("Network #{network_status}")
          say("Micro Cloud Foundry not configured\n\n")
        end
      end

      def network_status
        stat = @network.status.to_s
        case @network.status
        when :up
          stat.green
        when :failed
          stat.red
        else
          stat.yellow
        end
      end

      def dns_status
        if @identity.ip != VCAP::Micro::Network.local_ip
          "DNS out of sync".red
        else
          "ok".green
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
            if @memory.changed?
              menu.choice("reconfigure memory".yellow) { configure_memory }
            end
            menu.choice("reconfigure vcap password") { configure_password }
            menu.choice("reconfigure domain") { configure_domain }
            menu.choice("reconfigure network [#{@network.type}]") { configure_network }
            menu.choice("reconfigure proxy [#{@proxy.name}]") { configure_proxy }
            menu.choice("service status [#{service_status}]") { display_services }
            menu.choice("restart network") { restart }
            menu.choice("restore defaults") { defaults }
          end
          menu.choice("help") { display_help }
          menu.choice("shutdown VM") { shutdown }
          menu.hidden("debug") { debug_menu }
        end
      end

      def configure
        configure_password(true)
        configure_network(true)
        configure_memory(true) if @memory.changed?
        configure_proxy(true)
        configure_domain(true)
        say("\nInstalling Micro Cloud Foundry: will take up to five minutes\n\n")
        # TODO use a progres bar
        VCAP::Micro::Agent.apply(@identity)
        say("Installation complete\n".green)
        press_return_to_continue
      end

      def configure_password(initial=false)
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
        press_return_to_continue unless initial
      end

      def configure_domain(initial=false)
        unless initial
          say("\nCreate a new domain or regenerate a token for an existing")
          say("at www.cloudfoundry.com/micro\n")
        end
        @identity.clear
        token = ask("\nEnter Micro Cloud Foundry configuration token: ")
        if token == "quit" && ! initial
          return
        elsif token == "vcap.me"
          @identity.vcap_me
        else
          @identity.nonce = token
          @identity.install(VCAP::Micro::Network.local_ip)
        end
        @identity.save
        unless initial
          say("Reconfiguring Micro Cloud Foundry with new settings...")
          Bosh::Agent::Monit.stop_services # is it enough to stop only cc?
          VCAP::Micro::Agent.apply(@identity)
          press_return_to_continue
        end
      rescue SocketError
        say("Unable to contact cloudfoundry.com to redeem configuration token".red)
        retry unless are_you_sure?("Configure vcap.me instead?")
        @identity.vcap_me
        @identity.save
        say("Micro Cloud Foundry is now bound to localhost (127.0.0.1)".yellow)
        say("You must use ssh tunneling to access it")
        press_return_to_continue
      rescue RestClient::ResourceNotFound, RestClient::Forbidden, RestClient::Conflict
        say("Enter \"quit\" to cancel") unless initial
        retry
      end

      def configure_network(initial=false)
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
        press_return_to_continue unless initial
      end

      def configure_proxy(initial=false)
        old_url = @proxy.url
        while true
          url = ask("\nHTTP proxy: ") { |q| q.default = "none" }
          @proxy.url = url
          if @proxy.url
            break
          else
            say("Invalid proxy! Should start with http://\n".red)
          end
        end
        @proxy.save
        if !initial && old_url != @proxy.url
          say("Reconfiguring Micro Cloud Foundry with new proxy setting...")
          Bosh::Agent::Monit.stop_services
          VCAP::Micro::Agent.apply(@identity)
          press_return_to_continue
        end
      end

      def configure_memory(initial=false)
        mem = @memory.current
        say("Reconfiguring Micro Cloud Foundry with new memory: #{mem}")
        @memory.save_spec(@memory.update_spec(mem))
        @memory.update_previous
        unless initial
          Bosh::Agent::Monit.stop_services
          VCAP::Micro::Agent.apply(@identity)
          press_return_to_continue
        end
      end

      def configure_api_url
        while true
          host = ask("\nNew API host:") do |q|
            q.default = Identity::DEFAULT_API_HOST
          end

          if host == "quit"
            say("Nevermind then...")
            break
          elsif Network.lookup(host)
            @identity.update_api_host(host)
            # request new token here too?
            break
          else
            say("Could not resolve '#{host}', please try a different host")
            say("or use 'quit' to abort\n")
          end
        end
        press_return_to_continue
      end

      def refresh_dns
        @identity.update_ip(Network.local_ip)
        press_return_to_continue
      end

      def restart
        @network.restart
        press_return_to_continue
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
        return unless are_you_sure?("Are you sure you want to restore default settings?")
        @identity.clear
        @identity.save
        @network.dhcp
        @proxy.url = "none"
        @proxy.save
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
        return unless are_you_sure?("Really shut down VM? ")
        clear
        if @identity.configured?
          say("Stopping Cloud Foundry services...")
          Bosh::Agent::Monit.stop_services
          sleep 5 # TODO loop and wait until all are stopped
        end
        say("shutting down VM...")
        `poweroff`
        sleep 3600 # until the cows come home
      end

      DEBUG_LEVELS = %w[DEBUG INFO WARN ERROR FATAL UNKNOWN]
      def debug_menu
        while true
          clear
          say("Debug menu\n".red)
          say("Log file: #{LOGFILE}\n".yellow)
          choose do |menu|
            menu.prompt = "\nSelect debug option: "
            menu.select_by = :index
            level = DEBUG_LEVELS[@logger.level]
            menu.choice("set debug level to DEBUG [#{level}]") { debug_level }
            menu.choice("display log") { display_debug_log }
            menu.choice("change api url") { configure_api_url }
            menu.choice("return to main menu") { return }
          end
        end
      end

      def debug_level
        @logger.level = Logger::DEBUG
        @logger.info("debug output enabled")
        say("Debug output enabled in #{LOGFILE}")
        press_return_to_continue
      end

      def display_debug_log
        lines = nil
        File.open(LOGFILE) do |file|
          lines = file.readlines
        end
        current = 0
        while true
          clear
          say("#{LOGFILE}\n".yellow)
          say(lines[current..(current+20)].join)
          q = ask("\n Return for next page, 'last' for last page or 'quit' to quit: ")
          return if q.match(/^q(uit)*/i)
          current += 20 if q.empty?
          current = lines.size - 20 if q.match(/^l(ast)*/i)
        end
      end

      def clear
        print "\e[H\e[2J"
      end

      def press_return_to_continue
        ask("Press return to continue ")
      end

      def are_you_sure?(question)
        ask("#{question} ").match(/^y(es)*$/i)
      end
    end
  end
end

if $0 == __FILE__
  VCAP::Micro::Console.run
end
