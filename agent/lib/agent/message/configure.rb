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
        @logger = Bosh::Agent::Config.logger
        @base_dir = Bosh::Agent::Config.base_dir

        FileUtils.mkdir_p(File.join(@base_dir, 'bosh'))
        @settings_file = File.join(@base_dir, 'bosh', 'settings.json')
      end

      def configure
        @logger.info("Configuring instance")
        if File.exist?(@settings_file)
          load_settings
        else
          load_ovf
        end
        @logger.info("Loaded settings: #{@settings.inspect}")

        if @settings
          update_agent_id
          update_hostname
          update_bosh_server
          update_blobstore
          setup_networking
          update_time
          setup_data_disk
        end
        { "settings" => @settings }
      end

      def load_settings
        json_props = File.read(@settings_file)
        @settings = Yajl::Parser.new.parse(json_props)
      end

      def load_ovf
        ovf_env = info_get_ovfenv
        unless ovf_env.empty?
          doc = REXML::Document.new(ovf_env)
          xpath = '//oe:Environment/oe:PropertySection/oe:Property[@key="Bosh_Agent_Properties"]'
          element = REXML::XPath.first(doc, xpath,
                                          {'oe' => 'http://schemas.dmtf.org/ovf/environment/1'})
          json_props = element.attribute('value', 'http://schemas.dmtf.org/ovf/environment/1').value

          File.open(@settings_file, 'w') do |sfh|
            sfh.write(json_props)
          end

          @settings = Yajl::Parser.new.parse(json_props)
        else
          @logger.info("Unable to read OVF properties")
        end
      end

      def info_get_ovfenv
        `vmware-rpctool "info-get guestinfo.ovfEnv"`
      end

      def update_agent_id
        Bosh::Agent::Config.agent_id = @settings["agent_id"]
      end

      def update_hostname
        `hostname #{@settings["agent_id"]}`
        File.open('/etc/hostname', 'w') { |f| f.puts(@settings["agent_id"]) }
      end

      def update_bosh_server
        ovf_redis = {
          :host => @settings["server"]["host"],
          :port =>  @settings["server"]["port"].to_s,
          :password => @settings["server"]["password"]
        }
        Bosh::Agent::Config.redis_options.merge!(ovf_redis)
      end

      def update_blobstore
        ovf_blobstore = @settings["blobstore"]["properties"]
        Bosh::Agent::Config.blobstore_options.merge!(ovf_blobstore)
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
        #mac_addresses = detect_mac_addresses
        mac_addresses = { "foo" => "eth0" }

        # last to update wins for now
        @dns = []

        @networks = @settings["networks"]
        @networks.each do |k, v|
          # mac = v["mac"]
          mac = "foo"

          if mac_addresses.key?(mac)
            v["interface"] = mac_addresses[mac]

            begin
              net_cidr = NetAddr::CIDR.create("#{v['ip']} #{v['netmask']}")
              v["network"] = net_cidr.network
              v["broadcast"] = net_cidr.broadcast

              @dns = v["dns"]
            rescue NetAddr::ValidationError => e
              raise Bosh::Agent::MessageHandlerError, e.to_s
            end
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
          %w{ip network netmask broadcast gateway}.each do |field|
            unless v[field] 
              raise Bosh::Agent::MessageHandlerError, "Missing network value for #{field} in #{v.inspect}"
            end
          end
        end
      end

      def write_ubuntu_network_interfaces
        template = ERB.new(INTERFACE_TEMPLATE, 0, '%<>')
        result = template.result(binding)
        network_updated = update_file(result, '/etc/network/interfaces')
        if network_updated
          @logger.info("Updated networking")
          restart_networking_service
        end
      end

      def restart_networking_service
        # ubuntu 10.04 networking startup/upstart stuff is quite borked
        # FIXME: add multi interface support later
        output = `service network-interface stop INTERFACE=eth0`
        output += `service network-interface start INTERFACE=eth0`
        @logger.info("Restarted networking: #{output}")
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

      def update_time
        ntp_servers = @settings['ntp'].join(" ")
        unless ntp_servers.empty?
          @logger.info("Configure ntp-servers: #{ntp_servers}")
          output = `ntpdate #{ntp_servers}`
          @logger.info(output)
        end
      end

      DATA_DISK = "/dev/sdb"
      def setup_data_disk
        swap_partition = "#{DATA_DISK}1"
        data_partition = "#{DATA_DISK}2"

        if File.blockdev?(DATA_DISK) 

          if Dir["#{DATA_DISK}[1-9]"].empty?
            @logger.info("Found unformatted drive")
            @logger.info("Partition #{DATA_DISK}")
            partition_disk(DATA_DISK, data_sfdisk_input)

            @logger.info("Create swap and data partitions")
            %x[mkswap #{swap_partition}]
            %x[mkfs.ext4 #{data_partition}]
          end

          @logger.info("Swapon and mount data partition")
          %x[swapon #{swap_partition}]
          %x[mkdir -p #{@base_dir}/data]
          %x[mount #{data_partition} #{@base_dir}/data]
        end
      end

      def partition_disk(dev, sfdisk_input)
        if File.blockdev?(dev)
          sfdisk_cmd = "echo \"#{sfdisk_input}\" | sfdisk -uM #{dev}"
          output = %x[#{sfdisk_cmd}]
          unless $? == 0
            @logger.info("failed to parition #{dev}")
            @logger.info(ouput)
          end
        end
      end

      def data_sfdisk_input
        ",#{mem_total.to_i/1024},S\n,,L\n"
      end

      def mem_total
        # MemTotal:        3952180 kB
        File.readlines('/proc/meminfo').first.split(/\s+/)[1]
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
    gateway <%= n["gateway"] %>
<% end %>

TEMPLATE

    end
  end
end
