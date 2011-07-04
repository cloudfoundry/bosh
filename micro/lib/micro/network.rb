require 'netaddr'
require 'socket'

module VCAP
  module Micro
    class Network

      A_ROOT_SERVER = '198.41.0.4'

      def self.local_ip(route = A_ROOT_SERVER)
        route ||= A_ROOT_SERVER
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
        UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
      rescue Errno::ENETUNREACH
        # happens on boot when dhcp hasn't completed when we get here
        # TODO avoid being stuck here forever
        sleep 3
        retry
      ensure
        Socket.do_not_reverse_lookup = orig
      end

      def self.gateway
        %x{netstat -rn 2>&1}.split("\n").each do |line|
          fields = line.split(/\s+/)
          if fields[0] =~ /^default|0\.0\.0\.0$/
            return fields[1]
          end
        end
        nil
      end

      def self.ping(host, count=3)
        %x{ping -c #{count} #{host}}
        $? == 0
      end

      def self.lookup(name)
        IPSocket.getaddress(name)
      rescue SocketError
        nil
      end

      # states: down -> restarting -> up
      def initialize
        @state = :down
      end

      def restarting?
        @state == :restarting
      end

      def up?
        @state == :up
      end

      def dhcp
        write_network_interfaces(BASE_TEMPLATE + DHCP_TEMPLATE, nil)
        restart
      end

      def manual(net)
        begin
          cidr_ip_mask = "#{net['address']} #{net['netmask']}"

          net_cidr = NetAddr::CIDR.create(cidr_ip_mask)
          net['network'] = net_cidr.network
          net['broadcast'] = net_cidr.broadcast
        rescue NetAddr::ValidationError => e
          puts "hubba"
        end

        write_network_interfaces(BASE_TEMPLATE + MANUAL_TEMPLATE, net)

        if net['dns']
          dns(net['dns'])
        end
        restart
      end

      # Comma separated list of dns servers
      def dns(dns_string)
        servers = dns_string.split(/,/).map { |s| s.gsub(/\s+/, '') }
        File.open('/etc/resolv.conf', 'w') do |f|
          servers.each do |s|
            f.puts("nameserver #{s}")
          end
        end
      end

      def ntp(ntp_server)
      end

      def write_network_interfaces(template_data, net)
        interface_file = "/etc/network/interfaces"
        FileUtils.mkdir_p(File.dirname(interface_file))

        template = ERB.new(template_data, 0, '%<>')
        result = template.result(binding)
        File.open(interface_file, 'w') do |fh|
          fh.write(result)
        end
      end

      # TODO detect if restart hangs and set state to failed instead
      def restart
        raise RuntimeError, "network already restarting" if restarting?
        @state = :restarting
        `service network-interface stop INTERFACE=eth0 2>/dev/null`
        `service network-interface start INTERFACE=eth0`
        @state = :up
      end

      BASE_TEMPLATE = <<TEMPLATE
auto lo
iface lo inet loopback

TEMPLATE

     DHCP_TEMPLATE = <<TEMPLATE
auto eth0
iface eth0 inet dhcp
TEMPLATE

     MANUAL_TEMPLATE = <<TEMPLATE
auto eth0
iface eth0 inet static
address <%= net["address"]%>
network <%= net["network"] %>
netmask <%= net["netmask"]%>
broadcast <%= net["broadcast"] %>
gateway <%= net["gateway"] %>
TEMPLATE

    end
  end
end



