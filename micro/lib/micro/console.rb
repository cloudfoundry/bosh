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
require 'micro/dns'
require 'micro/service_manager'

module VCAP
  module Micro
    class Console

      def self.run
        Console.new.console
      end

      CC_CONFIG = "/var/vcap/jobs/cloud_controller/config/cloud_controller.yml"
      SBTA = "/var/vcap/micro/SBTA"
      TOS = "/var/vcap/micro/TOS"
      TOS_ACCEPTED = "/var/vcap/micro/.tos"
      LOGFILE = "/var/vcap/sys/log/micro/micro.log"

      def self.logger
        logfile = ENV['LOGFILE'] ? ENV['LOGFILE'] : LOGFILE
        FileUtils.mkdir_p(File.dirname(logfile))
        unless defined? @@logger
          @@logger = Logger.new(logfile, 5, 1024*100)
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
        @watcher = Watcher.new(@network, @identity)
        @svcmgr = ServiceManager.new
        @watcher.start
      end

      def console
        VCAP::Micro::Agent.start if @identity.configured?
        # TODO add a timeout so the console will be auto-refreshed
        while true
          clear
          say("              Welcome to VMware Micro Cloud Foundry version #{VCAP::Micro::Version::VERSION}\n\n")
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
        if Version.should_update?(@identity.version)
          url = "http://cloudfoundry.com/micro"
          say("Version #{@identity.latest_version} is available for download at #{url}\n".yellow)
        end
        if @identity.configured?
          say("Current Configuration:")
          say(" Identity:   #{@identity.subdomain} (#{dns_status})")
          admins = @identity.admins.nil? ? "none" : @identity.admins.join(', ')
          say(" Admin:      #{admins}")
          current = unless (ip = Network.local_ip) == @identity.ip
            "(actual #{ip})"
          else
            ""
          end
          say(" IP Address: #{@identity.ip} (network #{network_status}) #{current}\n\n")
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
        stat += " / #{@network.online_status}" unless @network.online?
        stat
      end

      def dns_status
        if !@network.online? # dont't warn when offline
          "ok".green
        elsif @identity.ip != VCAP::Micro::Network.local_ip
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
            menu.choice("#{@network.online? ? "enable" : "disable"} offline mode") { @network.toggle_online_status }
            menu.choice("reconfigure proxy [#{@proxy.name}]") { configure_proxy }
            menu.choice("services [#{@svcmgr.status_summary}]") { @svcmgr.service_menu }
            menu.choice("restart network") { restart }
            menu.choice("restore defaults") { defaults }
          end
          menu.choice("expert menu") { expert_menu }
          menu.choice("help") { display_help }
          menu.choice("shutdown VM") { shutdown }
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
        VCAP::Micro::Agent.randomize_passwords
        VCAP::Micro::Agent.apply(@identity)
        say("Installation complete\n".green)
        press_return_to_continue
      end

      def configure_password(initial=false)
        password = "foo"
        confirmation = "bar"
        say("\nSet password Micro Cloud Foundry VM user (vcap)")
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
        ip = VCAP::Micro::Network.local_ip
        unless initial
          say("\nCreate a new domain or regenerate a token for an existing")
          say("at my.cloudfoundry.com/micro\n")
        end
        # make sure we get a String not a HighLine::String
        token = ask("\nEnter Micro Cloud Foundry configuration token or offline domain name:").to_s
        if token == "quit" && ! initial
          return
        elsif token =~ /[^\.]+\.[^\.]+/
          # TODO sanity check of admin email
          # make sure we get a String not a HighLine::String
          email = ask("\nAdmin email: ").to_s

          while !tos_accepted?
            display_file(TOS, true)
            if agree("\nDo you agree to the Terms of Service? ")
              FileUtils.touch(TOS_ACCEPTED)
            else
              say("You have to agree to the Terms of Service to use Micro Cloud Foundry".red)
            end
          end

          @identity.clear
          @network.offline!
          @identity.offline(ip, token, email)
        else
          @identity.clear
          @identity.nonce = token
          @network.online!
          @identity.install(ip)
          # TOS implicitly accepted as the user has been to the cf.com web site
          FileUtils.touch(TOS_ACCEPTED)
        end
        @identity.save
        DNS.new(ip, @identity.subdomain).generate
        unless initial
          say("Reconfiguring Micro Cloud Foundry with new settings...")
          Bosh::Agent::Monit.stop_services(60) # is it enough to stop only cc?
          wait_for_monit
          VCAP::Micro::Agent.apply(@identity)
          press_return_to_continue
        end
      rescue SocketError => e
        say("Unable to contact cloudfoundry.com to redeem configuration token".red)
        @logger.error("SockerError: #{e}")
        retry if initial
        retry unless are_you_sure?("Configure in offline mode using a domain instead?")
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

            # make sure we get a String not a HighLine::String
            net['address'] = ask("Address: ").to_s
            net['netmask'] = ask("Netmask: ").to_s
            net['gateway'] = ask("Gateway: ").to_s
            net['dns'] =     ask("DNS:     ").to_s
            # TODO validate network
            @network.static(net)
          end
        end
        press_return_to_continue unless initial
      end

      def configure_proxy(initial=false)
        old_url = @proxy.url
        while true
          # make sure we get a String not a HighLine::String
          url = ask("\nHTTP proxy: ") { |q| q.default = "none" }.to_s
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
          Bosh::Agent::Monit.stop_services(60)
          wait_for_monit
          VCAP::Micro::Agent.apply(@identity)
          press_return_to_continue
        end
      end

      def configure_memory(initial=false)
        mem = @memory.current
        say("Reconfiguring Micro Cloud Foundry with new memory: #{mem}")
        say("Will take up to 5 minutes...")
        @memory.save_spec(@memory.update_spec(mem))
        @memory.update_previous
        unless initial
          Bosh::Agent::Monit.stop_services(60)
          wait_for_monit
          VCAP::Micro::Agent.apply(@identity)
          press_return_to_continue
        end
      end

      def refresh_dns
        if @network.online?
          @identity.update_ip(Network.local_ip)
        else
          say("Can't refresh DNS when offline".red)
        end
        press_return_to_continue
      end

      def restart
        @network.restart
        press_return_to_continue
      end

      def defaults
        return unless are_you_sure?("Are you sure you want to restore default settings?")
        say("Stopping Cloud Foundry services...")
        Bosh::Agent::Monit.stop_services(60)
        wait_for_monit
        @identity.clear
        @network.dhcp
        @proxy.url = "none"
        @proxy.save
        @network.offline!
        FileUtils.rm_rf(Identity::MICRO_CONFIG)
        Dir.glob("/var/vcap/data/*").each do |dir|
          FileUtils.rm_rf(dir) unless dir.match(/cache/)
        end
        Dir.glob("/var/vcap/sys/log/*").each do |dir|
          FileUtils.rm_rf(dir) unless dir.match(/micro/)
        end
        %w{/var/vcap/sys/run /var/vcap/store /var/vcap/jobs
           /var/vcap/packages
        }.each do |dir|
          FileUtils.rm_rf(dir)
        end
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
          Bosh::Agent::Monit.stop_services(60)
          wait_for_monit
        end
        say("shutting down VM...")
        `poweroff`
        sleep 3600 # until the cows come home
      end

      DEBUG_LEVELS = %w[DEBUG INFO WARN ERROR FATAL UNKNOWN]
      def expert_menu
        while true
          clear
          say("Expert menu\n".red)
          say("Log file: #{LOGFILE}\n".yellow)
          choose do |menu|
            menu.prompt = "\nSelect option: "
            menu.select_by = :index
            level = DEBUG_LEVELS[@logger.level]
            menu.choice("set debug level to DEBUG [#{level}]") { debug_level }
            menu.choice("display log") { display_file(LOGFILE) }
            menu.choice("change api url") { configure_api_url }
            state = @watcher.paused ? "enable" : "disable"
            menu.choice("#{state} network watcher") { toggle_watcher }
            menu.choice("reapply configuration") { reapply }
            menu.choice("toggle cloud controller user registration") { toggle_cc_registration }
            menu.choice("network trouble shooting") { network_troubleshooting }
            # nasty hack warning:
            # exec-ing causes the console program to restart when dpkg-reconfigrue exits
            menu.choice("change keyboard layout") do
              ENV['TERM'] = 'linux' # make sure we have a usable terminal type
              exec "dpkg-reconfigure console-data"
            end
            menu.choice("return to main menu") { return }
          end
          press_return_to_continue
        end
      end

      def debug_level
        @logger.level = Logger::DEBUG
        @logger.info("debug output enabled")
        say("Debug output enabled")
      end

      def configured?
        File.exist?(CC_CONFIG)
      end

      def tos_accepted?
        File.exist?(TOS_ACCEPTED)
      end

      def configure_api_url
        unless configured?
          say("You need to configure Micro Cloud Foundry before you can configure the api url".red)
          return
        end

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
      end

      def reapply
        unless configured?
          say("You need to configure Micro Cloud Foundry before you can reapply the configuration".red)
          return
        end

        @logger.info("reapplying configuration")
        say("Reapplying configuration, will take up to 5 minutes...")
        Bosh::Agent::Monit.stop_services(60)
        wait_for_monit
        VCAP::Micro::Agent.apply(@identity)
      end

      def toggle_watcher
        if @watcher.paused
          @watcher.resume
        else
          @watcher.pause
        end
      end

      def toggle_cc_registration
        unless configured?
          say("You need to configure Micro Cloud Foundry before you can disable account registration".red)
          return
        end

        say("Toggling cloud controller registration:")
        yaml = YAML.load_file(CC_CONFIG)
        yaml['allow_registration'] = !yaml['allow_registration']
        File.open(CC_CONFIG, 'w') { |f| f.write(YAML.dump(yaml))}
        # note that this doesn't persist across a reset to defaults
        say("Restarting cloud controller...")
        %x{monit restart cloud_controller}
      end

      # a very naïve pager
      LINES_PER_PAGE = 20
      def display_file(file, quit_on_end=false)
        lines = nil
        File.open(file) do |f|
          lines = f.readlines
        end
        if lines.size == 0
          say("file is empty")
          press_return_to_continue
        end
        current = 0
        while true
          clear
          say("#{file}\n".yellow)
          say(lines[current..(current+LINES_PER_PAGE)].join)
          if current + LINES_PER_PAGE >= lines.size
            say("end of file".green)
          end
          q = ask("\n Return for next page, 'last' for last page or 'quit' to quit: ")
          if q.match(/^q(uit)*/i)
            return
          elsif q.match(/^l(ast)*/i)
            current = lines.size - LINES_PER_PAGE
          elsif q.empty?
            current += LINES_PER_PAGE
            if current >= lines.size
              # last page
              return if quit_on_end
              if lines.size > LINES_PER_PAGE
                current = lines.size - LINES_PER_PAGE
              else
                current = 0
              end
            end
          end
        end
      end

      def network_troubleshooting
        clear
        say("Network troubleshooting\n".yellow)

        unless @identity.configured?
          say("Please configure Micro Cloud Foundry first...")
          return
        end

        # get IP
        ip = Network.local_ip
        ip_address = ip.to_s.green
        say("VM IP address is: #{ip_address}")
        say("configured IP address is: #{@identity.ip.green}")

        # get router IP
        gw = Network.gateway
        gateway = gw.to_s.green
        say("gateway IP address is: #{gateway}")

        # ping router IP
        ping = if Network.ping(gw, 1)
          "yes".green
        else
          "no".red
        end
        say("can ping gateway: #{ping}")

        say("configured domain: #{@identity.subdomain.green}")
        say("reverse lookup of IP address: #{Network.lookup(ip).to_s.green}")

        if @network.online?
          # DNS lookup
          url = @identity.subdomain
          ip = Network.lookup(url)
          say("DNS lookup of #{url} is #{ip.to_s.green}")

          # proxy
          say("proxy is #{@proxy.name.green}")
          say("configured proxy is #{RestClient.proxy}\n")

          # get URL (through proxy)
          url = "www.cloudfoundry.com"
          rest = RestClient::Resource.new("http://#{url}")
          rest["/"].get
          say("successfully got URL: #{url.green}")
        else
          puts "in offline mode - skipping DNS and remote connections"
        end

      rescue RestClient::Exception => e
        say("\nfailed to get URL: #{e.message}".red)
      rescue => e
        say("exception: #{e.message}".red)
        @logger.error(e.backtrace.join("\n"))
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

      # yuk - code duplication
      def wait_for_monit
        stopped = []
        loop do
          status = Bosh::Agent::Monit.retry_monit_request do |client|
            client.status(:group => Bosh::Agent::BOSH_APP_GROUP)
          end

          status.each do |name, data|
            @logger.debug("status: #{name}: #{data[:status]}")

            if stopped_service?(data)
              unless stopped.include?(name)
                puts "Stopped: #{name}"
                stopped << name
              end
            end
          end

          break if status.reject { |name, data| stopped_service?(data) }.empty?
          sleep 1
        end
      end

      def stopped_service?(data)
        data[:monitor] == :no
      end

    end
  end
end

if $0 == __FILE__
  VCAP::Micro::Console.run
end
