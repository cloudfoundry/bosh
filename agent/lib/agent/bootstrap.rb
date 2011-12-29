require 'rexml/document'
require 'netaddr'
require 'erb'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'openssl'

module Bosh::Agent
  class Bootstrap

    # TODO: set up iptables
    def initialize
      FileUtils.mkdir_p(File.join(base_dir, 'bosh'))
    end

    def logger
      Bosh::Agent::Config.logger
    end

    def base_dir
      Bosh::Agent::Config.base_dir
    end

    def store_path
      File.join(base_dir, 'store')
    end

    def configure
      logger.info("Configuring instance")

      load_settings
      logger.info("Loaded settings: #{@settings.inspect}")

      if @settings
        update_agent_id
        update_hostname
        update_mbus
        update_blobstore
        setup_networking
        update_time
        setup_data_disk
        setup_tmp

        Bosh::Agent::Monit.setup_monit_user
        Bosh::Agent::Monit.setup_alerts

        mount_persistent_disk
        harden_permissions
      end
      { "settings" => @settings }
    end

    def load_settings
      @settings = Bosh::Agent::Config.infrastructure.load_settings
      Bosh::Agent::Config.settings = @settings
    end

    def update_agent_id
      Bosh::Agent::Config.agent_id = @settings["agent_id"]
    end

    def update_hostname
      agent_id = @settings['agent_id']

      template = ERB.new(ETC_HOST_TEMPATE, 0, '%<>-')
      result = template.result(binding)
      File.open('/etc/hosts', 'w') { |f| f.puts(result) }

      `hostname #{agent_id}`
      File.open('/etc/hostname', 'w') { |f| f.puts(agent_id) }
    end

    def update_mbus
      Bosh::Agent::Config.mbus = @settings['mbus']
    end

    def update_blobstore
      blobstore_settings = @settings["blobstore"]

      blobstore_provider =  blobstore_settings["plugin"]
      blobstore_options =  blobstore_settings["properties"]

      Bosh::Agent::Config.blobstore_provider = blobstore_provider
      Bosh::Agent::Config.blobstore_options.merge!(blobstore_options)
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

            if v.key?('default') && v['default'].include?('dns')
              @dns = v["dns"]
            end
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

      # HACK to send a gratuitous arp every 10 seconds for the first minute
      # after networking has been reconfigured.
      Thread.new do
        6.times do
          gratuitous_arp
          sleep 10
        end
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

    def write_ubuntu_network_interfaces
      template = ERB.new(INTERFACE_TEMPLATE, 0, '%<>-')
      result = template.result(binding)
      network_updated = update_file(result, '/etc/network/interfaces')
      if network_updated
        logger.info("Updated networking")
        restart_networking_service
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

    def gratuitous_arp
      @networks.each do |name, n|
        until File.exist?("/sys/class/net/#{n['interface']}")
          sleep 0.1
        end
        logger.info("arping -c 1 -U -I #{n['interface']} #{n['ip']}")
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
    def update_file(data, path)
      name = File.basename(path)
      dir = File.dirname(path)

      if_tmp_file = Tempfile.new(name, dir)
      if_tmp_file.write(data)
      if_tmp_file.flush

      old = nil
      begin
        old = Digest::SHA1.file(path).hexdigest
      rescue Errno::ENOENT
        logger.debug("missing file: #{path}")
      end
      new = Digest::SHA1.file(if_tmp_file.path).hexdigest

      updated = false
      unless old == new
        FileUtils.cp(if_tmp_file.path, path)
        updated = true
      end
      if_tmp_file.close
      FileUtils.rm_rf(if_tmp_file.path)
      updated
    end

    def update_time
      ntp_servers = @settings['ntp'].join(" ")
      unless ntp_servers.empty?
        logger.info("Configure ntp-servers: #{ntp_servers}")
        update_file(ntp_servers, '/var/vcap/bosh/etc/ntpserver')
        output = `ntpdate #{ntp_servers}`
        logger.info(output)
      else
        logger.warning("no ntp-servers configured")
      end
    end

    DATA_DISK = "/dev/sdb"
    def setup_data_disk
      swap_partition = "#{DATA_DISK}1"
      data_partition = "#{DATA_DISK}2"

      if File.blockdev?(DATA_DISK)

        if Dir["#{DATA_DISK}[1-9]"].empty?
          logger.info("Found unformatted drive")
          logger.info("Partition #{DATA_DISK}")
          Bosh::Agent::Util.partition_disk(DATA_DISK, data_sfdisk_input)

          logger.info("Create swap and data partitions")
          %x[mkswap #{swap_partition}]
          %x[/sbin/mke2fs -t ext4 -j #{data_partition}]
        end

        logger.info("Swapon and mount data partition")
        %x[swapon #{swap_partition}]
        %x[mkdir -p #{base_dir}/data]

        data_mount = "#{base_dir}/data"
        unless Pathname.new(data_mount).mountpoint?
          %x[mount #{data_partition} #{data_mount}]
        end

        setup_data_sys
      end
    end

    def data_sfdisk_input
      ",#{swap_size},S\n,,L\n"
    end

    def swap_size
      disk_size = Util.block_device_size(DATA_DISK)
      if mem_total > disk_size/2
        return (disk_size/2)/1024
      else
        return mem_total/1024
      end
    end

    def mem_total
      # MemTotal:        3952180 kB
      File.readlines('/proc/meminfo').first.split(/\s+/)[1].to_i
    end

    def setup_data_sys
      %w{log run}.each do |dir|
        path = "#{base_dir}/data/sys/#{dir}"
        %x[mkdir -p #{path}]
        %x[chown root:vcap #{path}]
        %x[chmod 0750 #{path}]
      end
      %x[ln -nsf #{base_dir}/data/sys #{base_dir}/sys]
    end

    def setup_tmp
      # use a custom TMPDIR for agent itself
      agent_tmp_dir = File.join(base_dir, 'data', 'tmp')
      FileUtils.mkdir_p(agent_tmp_dir)
      ENV["TMPDIR"] = agent_tmp_dir

      # first time: for /tmp on the root fs
      tmp_permissions

      unless Pathname.new('/tmp').mountpoint?
        tmp_size = 128
        root_tmp = File.join(base_dir, 'data', 'root_tmp')

        # If it's not mounted on /tmp - we don't care - blow it away
        %x[/usr/bin/truncate -s #{tmp_size}M #{root_tmp}]
        %x[chmod 0700 #{root_tmp}]
        %x[mke2fs -t ext4 -m 1 -F #{root_tmp}]

        %x[mount -t ext4 -o loop #{root_tmp} /tmp]

        # 2nd time for the new /tmp mount
        tmp_permissions
      end
    end

    def tmp_permissions
      %x[chown root:#{BOSH_APP_USER} /tmp]
      %x[chmod 0770 /tmp]
      %x[chmod 0700 /var/tmp]
    end

    def mount_persistent_disk
      if @settings['disks']['persistent'].keys.size > 1
        # hell on earth
        raise Bosh::Agent::FatalError, "Fatal: more than one persistent disk on boot"
      else
        cid = @settings['disks']['persistent'].keys.first
        if cid
          Bosh::Agent::Config.platform.mount_persistent_disk(cid)
        end
      end
    end

    def harden_permissions
      setup_cron_at_allow

      # use this instead of removing vcap from the cdrom group, as there
      # is no way to easily do that from the command line
      root_only_rw = %w{
        /dev/sr0
      }
      root_only_rw.each do |path|
        %x[chmod 0660 #{path}]
        %x[chown root:root #{path}]
      end

      root_app_user_rw = %w{
        /dev/log
      }
      root_app_user_rw.each do |path|
        %x[chmod 0660 #{path}]
        %x[chown root:#{BOSH_APP_USER} #{path}]
      end

      root_app_user_rwx = %w{
        /dev/shm
        /var/lock
      }
      root_app_user_rwx.each do |path|
        %x[chmod 0770 #{path}]
        %x[chown root:#{BOSH_APP_USER} #{path}]
      end

      root_rw_app_user_read = %w{
        /etc/cron.allow
        /etc/at.allow
      }
      root_rw_app_user_read.each do |path|
        %x[chmod 0640 #{path}]
        %x[chown root:#{BOSH_APP_USER} #{path}]
      end

      no_other_read = %w{
        /data/vcap/data
        /data/vcap/store
      }
      no_other_read.each do |path|
        %[chmod o-r #{path}]
      end

    end

    def setup_cron_at_allow
      %w{/etc/cron.allow /etc/at.allow}.each do |file|
        File.open(file, 'w') { |fh| fh.puts(BOSH_APP_USER) }
      end
    end

    ETC_HOST_TEMPATE = <<TEMPLATE
127.0.0.1 localhost <%= agent_id %>

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback <%= agent_id %>
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
TEMPLATE

    INTERFACE_TEMPLATE = <<TEMPLATE
auto lo
iface lo inet loopback

<% @networks.each do |name, n| -%>
auto <%= n["interface"] %>
iface <%= n["interface"] %> inet static
    address <%= n["ip"]%>
    network <%= n["network"] %>
    netmask <%= n["netmask"]%>
    broadcast <%= n["broadcast"] %>
<% if n.key?('default') && n['default'].include?('gateway') -%>
    gateway <%= n["gateway"] %>
<% end %>
<% end -%>
TEMPLATE

  end
end
