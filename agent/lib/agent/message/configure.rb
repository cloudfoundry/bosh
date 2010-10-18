require 'rexml/document'
require 'netaddr'
require 'erb'
require 'tempfile'
require 'fileutils'

module Bosh::Agent
  module Message
    class Configure
      def self.process(args)
        self.new(args).configure
      end

      # TODO: set up iptables
      def initialize(args)
      end

      def configure
        load_ovf
        update_agent_id
        setup_networking
      end

      def load_ovf
        ovf_env = info_get_ovfenv
        doc = REXML::Document.new(ovf_env)
        xpath = '//oe:Environment/oe:PropertySection/oe:Property[@key="Bosh_Agent_Properties"]'
        element = REXML::XPath.first(doc, xpath,
                                        {'oe' => 'http://schemas.dmtf.org/ovf/environment/1'})
        json_props = element.attribute('value', 'http://schemas.dmtf.org/ovf/environment/1').value
        @settings = Yajl::Parser.new.parse(json_props)
      end

      def info_get_ovfenv
        `vmtoolsd --cmd "info-get guestinfo.ovfEnv"`
      end

      def update_agent_id
        Bosh::Agent::Config.agent_id = @settings["agent_id"]
      end

      # TODO: factor out into it's own class
      def detect_mac_addresses
        mac_addresses = {}
        Dir['/sys/class/net/*'].each do |dev_path|
          dev = File.basename(dev_path)
          mac = File.read(File.join(dev_path, 'address')).strip
          mac_addresses[mac] = dev
        end
        mac_addresses
      end

      def setup_networking
        mac_addresses = detect_mac_addresses

        # last to update wins for now
        @dns = []

        @networks = @settings["networks"]
        @networks.each do |k, v|
          mac = v["mac"]
          if mac_addresses.key?(mac)
            v["interface"] = mac_addresses[mac]

            net_cidr = NetAddr::CIDR.create("#{v['ip']} 255.255.255.0")
            v["network"] = net_cidr.network
            v["broadcast"] = net_cidr.broadcast

            @dns = v["dns"]
          else
            raise Bosh::Agent::MessageHandlerError, "#{mac} from OVF not present in instance"
          end
        end

        verify_networks
        write_ubuntu_network_interfaces
        write_resolv_conf
      end

      def verify_networks
        # This only verifies that the fields has values
        @networks.each do |k, v|
          %w{ip network netmask broadcast gw}.each do |field|
            unless v[field] 
              raise Bosh::Agent::MessageHandlerError, "Missing network value for #{field} in #{v.inspect}"
            end
          end
        end
      end

      def write_ubuntu_network_interfaces
        template = ERB.new(INTERFACE_TEMPLATE, 0, '%<>')
        result = template.result(binding)
        update_file(result, '/etc/network/interfaces')
      end

      # TODO: do we need search option?
      def write_resolv_conf
        template = ERB.new("<% @dns.each do |server| %>\nnameserver <%= server %>\n<% end %>\n", 0, '%<>')
        result = template.result(binding)
        update_file(result, '/etc/resolv.conf')
      end

      # Poor mans idempotency
      # FIXME: fails if original file is missing
      def update_file(data, path)
        name = File.basename(path)
        dir = File.dirname(path)

        if_tmp_file = Tempfile.new(name, dir)
        if_tmp_file.write(data)
        if_tmp_file.flush

        old = Digest::SHA1.hexdigest(File.read(path))
        new = Digest::SHA1.hexdigest(File.read(if_tmp_file.path))

        updated = false
        unless old == new
          FileUtils.cp(if_tmp_file.path, path)
          updated = true
        end
        if_tmp_file.close
        updated
      end

      def print_settings
        p @settings
        # For OVF test fixtures
        p Yajl::Encoder.encode(@settings).gsub(/\"/, "&quot;")
      end

      INTERFACE_TEMPLATE = <<TEMPLATE
auto lo
iface lo inet loopback

<% @networks.each do |name, n| %>
auto <%= n["interface"] %>
iface <%= n["interface"] %> inet static
    address <%= n["ip"]%>
    network <%= n["network"] %>
    netmask <%= n["netmask"]%>
    broadcast <%= n["broadcast"] %>
    gateway <%= n["gw"] %>
<% end %>

TEMPLATE

    end
  end
end
