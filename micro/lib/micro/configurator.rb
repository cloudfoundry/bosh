require 'highline/import'
require 'micro/network'
require 'micro/identity'
require 'micro/agent'
require 'micro/settings'
require 'micro/watcher'
require 'micro/version'

module VCAP
  module Micro
    class Configurator

      def initialize
        @identity = Identity.new
      end

      def run
        # TODO: check highline's signal handling - might get in the way here
        %w{TERM INT}.each { |sig| trap(sig) { puts "Exiting Micro Cloud Foundry Configurator"; exit } }

        begin
          clear

          if @identity.configured?
            current_ip = VCAP::Micro::Network.local_ip

            unless current_ip == @identity.ip
              @identity.install(current_ip)
            end

            VCAP::Micro::Agent.start
          end

          header
          password # TODO OS auth/pwchange/pam auth
          identity

          network
          @ip = VCAP::Micro::Network.local_ip

          if @identity.configured?
            @watcher = Watcher.new(@network, @identity).watch
          end

          if install_identity
            setup_admin
            install_micro

            @identity.save
          end
        rescue SystemExit => e
          say("\nRestarting console...")
        rescue Exception => e
          # FIXME: crude hack to prevent console to restart and clear
          say("\nWARNING: Failed to configure Micro Cloud Foundry:\n")
          puts e
          puts e.backtrace.join("\n")
          STDIN.getc
          exit(1)
        end
      end

      def header
        say("Welcome to VMware Micro Cloud Foundry version #{VCAP::Micro::VERSION}\n\n")

        unless @identity.configured?
          say("Please visit http://CloudFoundry.com register for a Micro Cloud Foundry token.\n\n")
          exit unless agree("Micro Cloud Foundry Not Configured - Do you want to configure? (y/n) ")
        else
          say("Target Micro Cloud Foundry: vmc http://api.#{@identity.subdomain}\n\n")

          current_configuration
          exit unless agree("\nRe-configure Micro Cloud Foundry? (y/n): ")
        end
      end

      def current_configuration
        say("Current Configuration:\n")
        say("  Identity : #{@identity.subdomain}\n")
        say("  Admin    : #{@identity.admins.join(', ')}\n")
        say("  Address  : #{@identity.ip}\n")

        begin
          current_ip = VCAP::Micro::Network.local_ip
          if current_ip != @identity.ip
            say("WARNING: Current IP Address (#{current_ip}) differs from configured IP")
          end
        rescue
          # TODO: check what local_ip does if no network exist.
        end
      end

      def password
        # TODO: check if default has already been changed
        # TODO: ask for password if set 

        unless @identity.configured?
          pass = ask("\nConfigure Micro Cloud Foundry Password:  ") { |q| q.echo = "*" }
          # BIG HACK
          `echo "root:#{pass}\nvcap:#{pass}" | chpasswd`
        end
      end

      def identity
        token = ask("\nMicro Cloud Foundry configuration token:")
        @identity.nonce = token
      end

      def network
        say("\nConfigure Micro Cloud Foundry networking")
        choose do |menu|
          menu.prompt = "Type: "
          menu.choice(:dhcp) { dhcp_network }
          menu.choice(:manual) { manual_network }
        end

        @identity.proxy = ask("HTTP proxy: ") { |q| q.default = "none" }
      end

      def dhcp_network
        @network = VCAP::Micro::Network.new
        @network.dhcp
      end

      def manual_network
        net = Hash.new
        say("\nEnter network configuration (address/netmask/gateway/DNS)")

        net['address'] = ask("Address: ")
        net['netmask'] = ask("Netmask: ")
        net['gateway'] = ask("Gateway: ")
        net['dns'] =     ask("DNS:     ")

        @network = VCAP::Micro::Network.new
        @network.manual(net)
      end

      def install_identity
        @identity.install(@ip)
        true
      rescue SocketError => e
        say("\nError contacting micro.cloudfoundry.com")
        exit unless agree("Continue using vcap.me domain instead? ")
        @identity.vcap_me
        true
      rescue => e
        say("Error registering identity with micro.cloudfoundry.com\n")
        say("\nException: #{e.message}")
        # TODO this stack trace should go into a log file
        # say("\nBacktrace: #{e.backtrace.join("\n")}")
        STDIN.getc
        false
      end

      def setup_admin
        admin_email = ask("\nAdmin email (#{@identity.admins.first}): ")

        # One day we'll grow up and validate email addresses - just not today
        if admin_email.match(/@/)
          @identity.admins = [ admin_email.split(',') ]
        end
        say("\n")
      end

      def install_micro
        say("\n")
        current_configuration

        say("\nInstalling Micro Cloud Foundry...\n\n")

        VCAP::Micro::Agent.apply(@identity)
      end

      def clear
        print "\e[H\e[2J"
      end
    end
  end

end

if __FILE__ == $0
  VCAP::Micro::Configurator.new.run
end
