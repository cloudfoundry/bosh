# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux'

module Bosh::Agent
  class Platform::Linux::Network

    def initialize(template_dir)
      @template_dir   = template_dir
      @config         = Bosh::Agent::Config
      @infrastructure = @config.infrastructure
      @logger         = @config.logger
      @networks       = []
      @dns            = []
    end

    def setup_networking
      case @config.infrastructure_name
        when "vsphere"
          setup_networking_from_settings
        when "aws"
          setup_dhcp_from_settings
        when "openstack"
          setup_dhcp_from_settings
        else
          raise Bosh::Agent::FatalError, "Setup networking failed, unsupported infrastructure #{Bosh::Agent::Config.infrastructure_name}"
      end
    end

    private
    def setup_networking_from_settings
      mac_addresses = detect_mac_addresses

      @dns = []
      @networks = @config.settings["networks"]
      @networks.each do |_, v|
         mac = v["mac"]

        if mac_addresses.key?(mac)
          v["interface"] = mac_addresses[mac]

          begin
            net_cidr = NetAddr::CIDR.create("#{v['ip']} #{v['netmask']}")
            v["network"] = net_cidr.network
            v["broadcast"] = net_cidr.broadcast

            parse_dns(v)
          rescue NetAddr::ValidationError => e
            raise Bosh::Agent::FatalError, e.to_s
          end
        else
          raise Bosh::Agent::FatalError, "#{mac} from settings not present in instance"
        end
      end

      verify_networks
      write_network_interfaces
      write_resolv_conf
      gratuitous_arp
    end

    def setup_dhcp_from_settings
      @dns = []
      @networks = @config.settings["networks"]
      @networks.each do |_, settings|
        parse_dns(settings)
      end

      unless @dns.empty?
        write_dhcp_conf
      end
    end

    def parse_dns(settings)
      if settings.key?('default') && settings['default'].include?('dns')
        @dns = settings["dns"] if settings["dns"]
      end
    end

    def detect_mac_addresses
      mac_addresses = {}
      Dir['/sys/class/net/*'].each do |dev_path|
        dev = File.basename(dev_path)
        mac = File.read(File.join(dev_path, 'address')).strip
        mac_addresses[mac] = dev
      end
      mac_addresses
    end

    # TODO: do we need search option?
    def write_resolv_conf
      template = ERB.new("<% @dns.each do |server| %>\nnameserver <%= server %>\n<% end %>\n", 0, '%<>')
      result = template.result(binding)
      Bosh::Agent::Util::update_file(result, '/etc/resolv.conf')
    end

    def gratuitous_arp
      # HACK to send a gratuitous arp every 10 seconds for the first minute
      # after networking has been reconfigured.
      Thread.new do
        6.times do
          @networks.each do |name, network|
            until File.exist?("/sys/class/net/#{network['interface']}")
              sleep 0.1
            end

            arp_cmd = "arping -c 1 -U -I #{network['interface']} #{network['ip']}"
            @logger.info(arp_cmd)
            Bosh::Exec.sh "#{arp_cmd}"
          end
          sleep 10
        end
      end
    end

    def verify_networks
      # This only verifies that the fields has values
      @networks.each do |_, v|
        %w{ip network netmask broadcast}.each do |field|
          unless v[field]
            raise Bosh::Agent::FatalError, "Missing network value for #{field} in #{v.inspect}"
          end
        end
      end
    end

    def write_network_interfaces
      raise Bosh::Agent::UnimplementedMethod.new
    end

    def write_dhcp_conf
      raise Bosh::Agent::UnimplementedMethod.new
    end

    def load_erb(file)
      path = File.expand_path(file, @template_dir)
      File.open(path) do |f|
        f.read
      end
    end
  end
end
