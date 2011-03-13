require 'highline/import'
require 'micro/network'
require 'micro/identity'

module VCAP
  module Micro
    class Configurator

      def run
        # TODO: check highline's signal handling - might get in the way here
        %w{TERM INT}.each { |sig| trap(sig) { puts "Exiting Micro Cloud Configurator"; exit } }

        clear
        header
        summary
        password
        network

        # Network needs to be set up before we can proceed with identity
        identity
      end

      def header
        say("Welcome to VMware Micro Cloud Download\n\n")
      end

      def summary
        say("Please visit http://CloudFoundry.com register for a Micro Cloud Download token.\n\n")
      end

      def password
        # TODO: check if default has already been changed
        # TODO: ask for password if set 
        pass = ask("Configure Micro Cloud Password:  ") { |q| q.echo = "*" }
      end

      def network
        say("\nConfigure Micro Cloud networking")
        choose do |menu|
          menu.choice(:dhcp) { dhcp_network }
          menu.choice(:manual) { manual_network }
        end

        proxy = ask("HTTP proxy: ") { |q| q.default = "none" }
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

      def identity
        say("\nConfigure Micro Cloud identity\n")
        choose do |menu|
          menu.choice(:token) { token }
          menu.choice(:dns_wildcard_name) { dns_wildcard_name }
        end
        unless VCAP::Micro::Identity.admin?
          setup_admin
        end
      end

      def token
        token = ask("Token: ")
        VCAP::Micro::Identity.token(token)
      end

      def dns_wildcard_name
        name = ask("DNS wildcarded record: ")
        VCAP::Micro::Identity.dns_wildcard_name(name)
      end

      def setup_admin
        admin = ask("Admin email: ")
        VCAP::Micro::Identity.setup_admin(admin)
      end

      def start_micro_cloud
        #VCAP::Micro::Runner.start
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
