# Copyright (c) 2009-2012 VMware, Inc.

require 'rexml/document'
require 'netaddr'
require 'erb'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'openssl'

module Bosh::Agent
  class Bootstrap
    include Bosh::Exec

    def initialize
      FileUtils.mkdir_p(File.join(base_dir, 'bosh'))
      @platform = Bosh::Agent::Config.platform
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
        if Config.configure
          update_iptables
          update_passwords
          update_agent_id
          update_credentials
          update_hostname
          update_mbus
          update_blobstore
          setup_networking
          update_time
          setup_data_disk
          setup_data_sys
          setup_tmp

          Bosh::Agent::Monit.setup_monit_user
          Bosh::Agent::Monit.setup_alerts

          mount_persistent_disk
          harden_permissions
        else
          update_agent_id
          update_credentials
          update_mbus
          update_blobstore
        end
      end
      { "settings" => @settings }
    end

    def load_settings
      @settings = Bosh::Agent::Settings.load
      Bosh::Agent::Config.settings = @settings
    end

    def iptables(cmd)
      output = %x{iptables #{cmd} 2> /dev/null}
      if $?.exitstatus != 0
        raise Bosh::Agent::Error, "`iptables #{cmd}` failed"
      end
      output
    end

    def update_iptables
      return unless rules = @settings['iptables']

      if rules["drop_output"]
        chain = "agent-filter"
        append_chain = "-A OUTPUT -j #{chain}"

        begin
          iptables("-N #{chain}")
        rescue
          iptables("-F #{chain}")
        end

        unless iptables("-S").include?(append_chain)
          iptables(append_chain)
        end

        rules["drop_output"].each do |dest|
          rule = "-A #{chain} -d #{dest} -m owner ! --uid-owner root -j DROP"
          iptables(rule)
        end
      end
    end

    def update_passwords
      @platform.update_passwords(@settings) unless @settings["env"].nil?
    end

    def update_agent_id
      Bosh::Agent::Config.agent_id = @settings["agent_id"]
    end

    def update_credentials
      env = @settings["env"]
      if env && bosh_env = env["bosh"]
        if bosh_env["credentials"]
          Bosh::Agent::Config.credentials = bosh_env["credentials"]
        end
      end
    end

    def update_hostname
      agent_id = @settings['agent_id']

      template = ERB.new(ETC_HOST_TEMPLATE, 0, '%<>-')
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

      blobstore_provider =  blobstore_settings["provider"]
      blobstore_options =  blobstore_settings["options"]

      Bosh::Agent::Config.blobstore_provider = blobstore_provider
      Bosh::Agent::Config.blobstore_options.merge!(blobstore_options)
    end

    def setup_networking
      Bosh::Agent::Config.platform.setup_networking
    end

    def update_time
      ntp_servers = @settings['ntp'].join(" ")
      unless ntp_servers.empty?
        logger.info("Configure ntp-servers: #{ntp_servers}")
        Bosh::Agent::Util.update_file(ntp_servers, '/var/vcap/bosh/etc/ntpserver')
        output = `ntpdate #{ntp_servers}`
        logger.info(output)
      else
        logger.warn("no ntp-servers configured")
      end
    end

    def setup_data_disk
      data_mount = File.join(base_dir, "data")
      FileUtils.mkdir_p(data_mount)

      data_disk = Bosh::Agent::Config.platform.get_data_disk_device_name
      if data_disk
        unless File.blockdev?(data_disk)
          logger.warn("Data disk is not a block device: #{data_disk}")
          return
        end

        swap_partition = "#{data_disk}1"
        data_partition = "#{data_disk}2"

        swap_turned_on = sh("cat /proc/swaps | grep #{swap_partition}", :on_error => :return).success?
        data_partition_mounted = sh("mount | grep #{data_partition}", :on_error => :return).success?

        if Dir.glob("#{data_disk}[1-2]").empty?
          logger.info("Found unformatted drive")
          logger.info("Partition #{data_disk}")
          Bosh::Agent::Util.partition_disk(data_disk, data_sfdisk_input)

          logger.info("Create swap and data partitions")
          sh "mkswap #{swap_partition}"

          mke2fs_options = ["-t ext4", "-j"]
          mke2fs_options << "-E lazy_itable_init=1" if Bosh::Agent::Util.lazy_itable_init_enabled?
          sh "/sbin/mke2fs #{mke2fs_options.join(" ")} #{data_partition}"
        end

        unless swap_turned_on
          logger.info("Swapon partition #{swap_partition}")
          sh "swapon #{swap_partition}"
        end

        unless data_partition_mounted
          unless Pathname.new(data_mount).mountpoint?
            logger.info("Mount data partition #{data_partition} to #{data_mount}")
            sh "mount #{data_partition} #{data_mount}"
          end
        end
      end
    end

    def data_sfdisk_input
      ",#{swap_size},S\n,,L\n"
    end

    def swap_size
      data_disk = Bosh::Agent::Config.platform.get_data_disk_device_name
      disk_size = Util.block_device_size(data_disk)
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
      data_sys_dir = File.join(base_dir, 'data', 'sys')
      sys_dir = File.join(base_dir, 'sys')

      %w{log run}.each do |dir|
        path = File.join(data_sys_dir, dir)
        FileUtils.mkdir_p(path)
        FileUtils.chown('root', 'vcap', path)
        FileUtils.chmod(0750, path)
      end

      Bosh::Agent::Util.create_symlink(data_sys_dir, sys_dir)
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

    ETC_HOST_TEMPLATE = <<TEMPLATE
127.0.0.1 localhost <%= agent_id %>

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback <%= agent_id %>
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
TEMPLATE

  end
end
