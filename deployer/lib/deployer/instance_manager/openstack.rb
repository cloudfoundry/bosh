# Copyright (c) 2009-2012 VMware, Inc.

require 'net/ssh'

module Bosh::Deployer
  class InstanceManager

    class Openstack < InstanceManager

      def update_spec(spec)
        spec = super(spec)
        properties = spec["properties"]

        properties["openstack"] =
          Config.spec_properties["openstack"] ||
          Config.cloud_options["properties"]["openstack"].dup

        properties["openstack"]["registry"] = Config.cloud_options["properties"]["registry"]
        properties["openstack"]["stemcell"] = Config.cloud_options["properties"]["stemcell"]

        spec.delete("networks")

        spec
      end

      def configure
        properties = Config.cloud_options["properties"]
        @ssh_user = properties["openstack"]["ssh_user"]
        @ssh_port = properties["openstack"]["ssh_port"] || 22
        @ssh_wait = properties["openstack"]["ssh_wait"] || 60

        key = properties["openstack"]["private_key"]
        unless key
          raise ConfigError, "Missing properties.openstack.private_key"
        end
        @ssh_key = File.expand_path(key)
        unless File.exists?(@ssh_key)
          raise ConfigError, "properties.openstack.private_key '#{key}' does not exist"
        end

        uri = URI.parse(properties["registry"]["endpoint"])
        user, password = uri.userinfo.split(":", 2)
        @registry_port = uri.port

        @registry_db = Tempfile.new("openstack_registry_db")
        @registry_db_url = "sqlite://#{@registry_db.path}"

        registry_config = {
          "logfile" => "./openstack_registry.log",
          "http" => {
            "port" => uri.port,
            "user" => user,
            "password" => password
          },
          "db" => {
            "database" => @registry_db_url
          },
          "openstack" => properties["openstack"]
        }

        @registry_config = Tempfile.new("openstack_registry_yml")
        @registry_config.write(YAML.dump(registry_config))
        @registry_config.close
      end

      def start
        configure()

        Sequel.connect(@registry_db_url) do |db|
          migrate(db)
          servers = @deployments["openstack_servers"]
          db[:openstack_servers].insert_multiple(servers) if servers
        end

        unless has_openstack_registry?
          raise "openstack_registry command not found - " +
            "run 'gem install bosh_openstack_registry'"
        end

        cmd = "openstack_registry -c #{@registry_config.path}"

        @registry_pid = spawn(cmd)

        5.times do
          sleep 0.5
          if Process.waitpid(@registry_pid, Process::WNOHANG)
            raise Error, "`#{cmd}` failed, exit status=#{$?.exitstatus}"
          end
        end

        timeout_time = Time.now.to_f + (60 * 5)
        http_client = HTTPClient.new()
        begin
          http_client.head("http://127.0.0.1:#{@registry_port}")
          sleep 0.5
        rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
          if timeout_time - Time.now.to_f > 0
            retry
          else
            raise "Cannot access openstack_registry: #{e.message}"
          end
        end
        logger.info("openstack_registry is ready on port #{@registry_port}")
      ensure
        @registry_config.unlink if @registry_config
      end

      def stop
        if @registry_pid && process_exists?(@registry_pid)
          Process.kill("INT", @registry_pid)
          Process.waitpid(@registry_pid)
        end

        return unless @registry_db_url

        Sequel.connect(@registry_db_url) do |db|
          @deployments["openstack_servers"] = db[:openstack_servers].map {|row| row}
        end

        save_state
        @registry_db.unlink if @registry_db
      end

      def wait_until_agent_ready
        tunnel(@registry_port)
        super
      end

      def discover_bosh_ip
        if exists?
          server = cloud.openstack.servers.get(state.vm_cid)
          ip = server.public_ip_address
          ip = server.private_ip_address if ip.nil? || ip.empty?
          if ip.nil? || ip.empty?
            raise "Unable to discover bosh ip"
          else
            if ip["addr"] != Config.bosh_ip
              Config.bosh_ip = ip["addr"]
              logger.info("discovered bosh ip=#{Config.bosh_ip}")
            end
          end
        end

        super
      end

      def service_ip
        ip = cloud.openstack.servers.get(state.vm_cid).private_ip_address
        ip["addr"] unless ip.nil? || ip.empty?
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        # OpenStack stores disk size in GiB but we work with MiB
        cloud.openstack.volumes.get(cid).size * 1024
      end

      def persistent_disk_changed?
        # since OpenStack stores disk size in GiB and we use MiB there
        # is a risk of conversion errors which lead to an unnecessary
        # disk migration, so we need to do a double conversion
        # here to avoid that
        requested = (Config.resources['persistent_disk'] / 1024.0).ceil * 1024
        requested != disk_size(state.disk_cid)
      end

      private

      # TODO this code is similar to has_stemcell_copy?
      # move the two into bosh_common later
      def has_openstack_registry?(path=ENV['PATH'])
        path.split(":").each do |dir|
          return true if File.exist?(File.join(dir, "openstack_registry"))
        end
        false
      end

      def migrate(db)
        db.create_table :openstack_servers do
          primary_key :id
          column :server_id, :text, :unique => true, :null => false
          column :settings, :text, :null => false
        end
      end

      def process_exists?(pid)
        begin
          Process.kill(0, pid)
        rescue Errno::ESRCH
          false
        end
      end

      def socket_readable?(ip, port)
        socket = TCPSocket.new(ip, port)
        if IO.select([socket], nil, nil, 5)
          logger.debug("tcp socket #{ip}:#{port} is readable")
          yield
          true
        else
          false
        end
      rescue SocketError => e
        logger.debug("tcp socket #{ip}:#{port} SocketError: #{e.inspect}")
        sleep 1
        false
      rescue SystemCallError => e
        logger.debug("tcp socket #{ip}:#{port} SystemCallError: #{e.inspect}")
        sleep 1
        false
      ensure
        socket.close if socket
      end

      def tunnel(port)
        return if @session

        ip = discover_bosh_ip

        loop until socket_readable?(ip, @ssh_port) do
          #sshd is up, sleep while host keys are generated
          sleep @ssh_wait
        end

        lo = "127.0.0.1"
        cmd = "ssh -R #{port}:#{lo}:#{port} #{@ssh_user}@#{ip}"

        logger.info("Preparing for ssh tunnel: #{cmd}")
        loop do
          begin
            @session = Net::SSH.start(ip, @ssh_user, :keys => [@ssh_key],
                                      :paranoid => false)
            logger.debug("ssh #{@ssh_user}@#{ip}: ESTABLISHED")
            break
          rescue => e
            logger.debug("ssh start #{@ssh_user}@#{ip} failed: #{e.inspect}")
            sleep 1
          end
        end

        @session.forward.remote(port, lo, port)
        logger.info("`#{cmd}` started: OK")

        Thread.new do
          begin
            @session.loop { true }
          rescue IOError => e
            logger.debug("`#{cmd}` terminated: #{e.inspect}")
            @session = nil
          end
        end
      end

    end
  end
end
