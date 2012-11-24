# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Ubuntu::Network

    def initialize
    end

    def logger
      Bosh::Agent::Config.logger
    end

    def setup_networking
      case Bosh::Agent::Config.infrastructure_name
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

    def setup_networking_from_settings
      mac_addresses = detect_mac_addresses
      settings = Bosh::Agent::Config.settings

      @dns = []
      @networks = settings["networks"]
      @networks.each do |k, v|
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
      write_ubuntu_network_interfaces
      write_resolv_conf
      gratuitous_arp
    end

    def setup_dhcp_from_settings
      @dns = []
      @networks = Bosh::Agent::Config.settings["networks"]
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
            logger.info(arp_cmd)
            `#{arp_cmd}`
          end
          sleep 10
        end
      end
    end

    def write_ubuntu_network_interfaces
      template = ERB.new(load_erb("interfaces.erb"), 0, '%<>-')
      result = template.result(binding)
      network_updated = Bosh::Agent::Util::update_file(result, '/etc/network/interfaces')
      if network_updated
        logger.info("Updated networking")
        restart_networking_service
      end
    end

    def verify_networks
      # This only verifies that the fields has values
      @networks.each do |k, v|
        %w{ip network netmask broadcast}.each do |field|
          unless v[field]
            raise Bosh::Agent::FatalError, "Missing network value for #{field} in #{v.inspect}"
          end
        end
      end
    end

    def restart_networking_service
      # ubuntu 10.04 networking startup/upstart stuff is quite borked
      @networks.each do |k, v|
        interface = v['interface']
        logger.info("Restarting #{interface}")
        output = `service network-interface stop INTERFACE=#{interface}`
        output += `service network-interface start INTERFACE=#{interface}`
        logger.info("Restarted networking: #{output}")
      end
    end

    def write_dhcp_conf
      template = ERB.new(load_erb("dhclient_conf.erb"), 0, '%<>-')
      result = template.result(binding)
      updated = Bosh::Agent::Util::update_file(result, '/etc/dhcp3/dhclient.conf')
      if updated
        logger.info("Updated dhclient.conf")
        restart_dhclient
      end
    end

    # Executing /sbin/dhclient starts another dhclient process, so it'll cause
    # a conflict with the existing system dhclient process and dns changes will
    # be flip floping each lease time. So in order to refresh dhclient
    # configuration we need to restart networking.
    def restart_dhclient
      %x{/etc/init.d/networking restart}
    end

    def load_erb(file)
      dir = File.dirname(__FILE__)
      path = File.expand_path("templates/#{file}", dir)
      File.open(path) do |f|
        f.read
      end
    end
  end
end
