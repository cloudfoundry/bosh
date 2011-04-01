require 'highline/import'
require 'micro/network'
require 'micro/identity'
require 'micro/agent'
require 'micro/system'
require 'micro/settings'

module VCAP
  module Micro
    class Configurator

      def initialize
        @identity = Identity.new
      end

      def run
        # TODO: check highline's signal handling - might get in the way here
        %w{TERM INT}.each { |sig| trap(sig) { puts "Exiting Micro Cloud Configurator"; exit } }

        begin
          clear
          header
          password # TODO OS auth/pwchange/pam auth
          identity

          network
          mounts

          @ip = VCAP::Micro::Network.local_ip
          install_identity
          install_micro

          @identity.save
        rescue Exception => e
          # FIXME: crude hack to prevent console to restart and clear
          say("\nWARNING: Failed to configure Cloud Foundry Micro:\n")
          puts e
          puts e.backtrace
          STDIN.getc
          exit(1)
        end
      end

      def header
        say("BETA - Welcome to VMware Micro Cloud Download - BETA\n\n")

        unless @identity.configured?
          say("Please visit http://CloudFoundry.com register for a Micro Cloud token.\n\n")
          exit unless agree("Micro Cloud Not Configured - Do you want to configure? (y/n) ")
        else
          say("Target Micro Cloud: vmc http://api.#{@identity.subdomain}\n\n")

          current_configuration
          exit unless agree("\nRe-configure Micro Cloud? (y/n): ")
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
          pass = ask("Configure Micro Cloud Password:  ") { |q| q.echo = "*" }
          # BIG HACK
          `echo "root:#{pass}\nvcap:#{pass}" | chpasswd`
        end
      end

      def identity
        say("\nConfigure Micro Cloud identity:\n")
        choose do |menu|
          menu.prompt = "Choose identity type: "
          menu.choice(:token) { token }
          menu.choice(:dns_wildcard_name) { dns_wildcard_name }
        end
      end

      def token
        token = ask("Token: ")
        @identity.token(token)
      end

      def dns_wildcard_name
        name = ask("DNS wildcarded record: ")
        @identity.dns_wildcard_name(name)
      end

      def network
        say("\nConfigure Micro Cloud networking ")
        choose do |menu|
          menu.prompt = "Network type: "
          menu.choice(:dhcp) { dhcp_network }
          menu.choice(:manual) { manual_network }
        end

        @identity.proxy = ask("HTTP proxy: ") { |q| q.default = "none" }
      end

      def dhcp_network
        VCAP::Micro::Network.new.dhcp
      end

      def manual_network
        net = Hash.new
        say("Enter network configuration (address/netmask/gateway/DNS)")

        net['address'] = ask("Address: ")
        net['netmask'] = ask("Netmask: ")
        net['gateway'] = ask("Gateway: ")
        net['dns'] =     ask("DNS:     ")

        VCAP::Micro::Network.new.manual(net)
      end

      def mounts
        VCAP::Micro::System.mounts
      end

      def install_identity
        unless @identity.admins
          setup_admin
        end
        begin
          @identity.install(@ip)
        rescue => e
          say("Error registering identity with cf.vcloudlabs.com (will be www.cloudfoundry.com)\n")
          say("\nException: #{e.message}")
          say("\nBacktrace: #{e.backtrace}")
        end
      end

      def setup_admin
        admin_email = ask("\nAdmin email: ")
        @identity.admins = [ admin_email.split(',') ]
      end

      def install_micro
        say("\n")
        current_configuration

        say("\nInstalling CloudFoundry Micro...\n\n")

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
