require 'netaddr'

module VCAP
  module Micro
    class Network

      def dhcp
        write_network_interfaces(BASE_TEMPLATE + DHCP_TEMPLATE, nil)
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
      end

      # Comma separated list of dns servers
      def dns(dns_string)
      end

      def ntp(ntp_server)
      end

      def write_network_interfaces(template_data, net)
        interface_file = "/tmp/etc/network/interfaces"
        FileUtils.mkdir_p(File.dirname(interface_file))

        template = ERB.new(template_data, 0, '%<>') 
        result = template.result(binding)
        File.open('/tmp/etc/network/interfaces', 'w') do |fh|
          fh.write(result)
        end
      end

      def restart
        puts "service network-interface stop INTERFACE=eth0"
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



