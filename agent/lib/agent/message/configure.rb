require 'rexml/document'
require 'netaddr'
require 'erb'
require 'tempfile'
require 'fileutils'
require 'pathname'

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

        load_settings
        @logger.info("Loaded settings: #{@settings.inspect}")

        if @settings
          update_agent_id
          update_hostname
          update_bosh_server
          update_blobstore
          setup_networking
          update_time
          setup_data_disk

          # HACK HACK HACK - until we can identify store drive
          if File.blockdev?('/dev/sdc1')
            @logger.info("HACK: mount /dev/sdc1 /var/vmc/store")
            `mount /dev/sdc1 /var/vmc/store`
          end
        end
        { "settings" => @settings }
      end

      def load_settings
        begin
          @settings = Bosh::Agent::Util.settings
        rescue LoadSettingsError
          if File.exist?(@settings_file)
            load_settings_file
          else
            raise LoadSettingsError, "No cdrom or cached settings.json"
          end
        end
      end

      def load_settings_file
        settings_json = File.read(@settings_file)
        @settings = Yajl::Parser.new.parse(settings_json)
      end

      def update_agent_id
        Bosh::Agent::Config.agent_id = @settings["agent_id"]
      end

      def update_hostname
        `hostname #{@settings["agent_id"]}`
        File.open('/etc/hostname', 'w') { |f| f.puts(@settings["agent_id"]) }
      end

      def update_bosh_server
        redis_settings = {
          :host => @settings["server"]["host"],
          :port =>  @settings["server"]["port"].to_s,
          :password => @settings["server"]["password"]
        }
        Bosh::Agent::Config.redis_options.merge!(redis_settings)
      end

      def update_blobstore
        blobstore_settings = @settings["blobstore"]["properties"]
        Bosh::Agent::Config.blobstore_options.merge!(blobstore_settings)
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

            begin
              net_cidr = NetAddr::CIDR.create("#{v['ip']} #{v['netmask']}")
              v["network"] = net_cidr.network
              v["broadcast"] = net_cidr.broadcast

              @dns = v["dns"]
            rescue NetAddr::ValidationError => e
              raise Bosh::Agent::MessageHandlerError, e.to_s
            end
          else
            raise Bosh::Agent::MessageHandlerError, "#{mac} from settings not present in instance"
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

          # HACK to send a gratuitous arp every 10 seconds for the first minute
          # after networking has been reconfigured.
          Thread.new do
            6.times do
              gratuitous_arp
              sleep 10
            end
          end

        end
      end

      def restart_networking_service
        # ubuntu 10.04 networking startup/upstart stuff is quite borked
        # FIXME: add multi interface support later
        output = `service network-interface stop INTERFACE=eth0`
        output += `service network-interface start INTERFACE=eth0`
        @logger.info("Restarted networking: #{output}")
      end

      def gratuitous_arp
        @networks.each do |name, n|
          until File.exist?("/sys/class/net/#{n['interface']}")
            sleep 0.1
          end
          @logger.info("arping -c 1 -U -I #{n['interface']} #{n['ip']}")
          `arping -c 1 -U -I #{n['interface']} #{n['ip']}`
        end
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
            Bosh::Agent::Util.partition_disk(DATA_DISK, data_sfdisk_input)

            @logger.info("Create swap and data partitions")
            %x[mkswap #{swap_partition}]
            %x[mkfs.ext4 #{data_partition}]
          end

          @logger.info("Swapon and mount data partition")
          %x[swapon #{swap_partition}]
          %x[mkdir -p #{@base_dir}/data]

          data_mount = "#{@base_dir}/data"
          unless Pathname.new(data_mount).mountpoint?
            %x[mount #{data_partition} #{data_mount}]
          end

          %x[mkdir -p #{@base_dir}/data/log]
          %x[ln -nsf #{@base_dir}/data/log #{@base_dir}/sys/log]
        end
      end

      def data_sfdisk_input
        ",#{mem_total.to_i/1024},S\n,,L\n"
      end

      def mem_total
        # MemTotal:        3952180 kB
        File.readlines('/proc/meminfo').first.split(/\s+/)[1]
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
