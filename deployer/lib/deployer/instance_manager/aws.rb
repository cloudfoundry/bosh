# Copyright (c) 2009-2012 VMware, Inc.

require 'net/ssh'

module Bosh::Deployer
  class InstanceManager

    class Aws < InstanceManager

      def update_spec(spec)
        spec = super(spec)
        properties = spec["properties"]

        properties["aws"] =
          Config.spec_properties["aws"] ||
          Config.cloud_options["properties"]["aws"].dup

        properties["aws"]["registry"] = Config.cloud_options["properties"]["registry"]
        properties["aws"]["stemcell"] = Config.cloud_options["properties"]["stemcell"]

        spec.delete("networks")

        spec
      end

      def configure
        properties = Config.cloud_options["properties"]
        @ssh_user = properties["aws"]["ssh_user"]
        @ssh_port = properties["aws"]["ssh_port"] || 22
        @ssh_wait = properties["aws"]["ssh_wait"] || 60

        key = properties["aws"]["ec2_private_key"]
        unless key
          raise ConfigError, "Missing properties.aws.ec2_private_key"
        end
        @ssh_key = File.expand_path(key)
        unless File.exists?(@ssh_key)
          raise ConfigError, "properties.aws.ec2_private_key '#{key}' does not exist"
        end

        uri = URI.parse(properties["registry"]["endpoint"])
        user, password = uri.userinfo.split(":", 2)
        @registry_port = uri.port

        @registry_db = Tempfile.new("aws_registry_db")
        @registry_db_url = "sqlite://#{@registry_db.path}"

        registry_config = {
          "logfile" => "./aws_registry.log",
          "http" => {
            "port" => uri.port,
            "user" => user,
            "password" => password
          },
          "db" => {
            "database" => @registry_db_url
          },
          "aws" => properties["aws"]
        }

        @registry_config = Tempfile.new("aws_registry_yml")
        @registry_config.write(YAML.dump(registry_config))
        @registry_config.close
      end

      def start
        configure()

        Sequel.connect(@registry_db_url) do |db|
          migrate(db)
          instances = @deployments["aws_instances"]
          db[:aws_instances].insert_multiple(instances) if instances
        end

        unless has_aws_registry?
          raise "aws_registry command not found - " +
            "run 'gem install bosh_aws_registry'"
        end

        cmd = "aws_registry -c #{@registry_config.path}"

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
            raise "Cannot access aws_registry: #{e.message}"
          end
        end
        logger.info("aws_registry is ready on port #{@registry_port}")
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
          @deployments["aws_instances"] = db[:aws_instances].map {|row| row}
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
          ip = cloud.ec2.instances[state.vm_cid].public_ip_address
          if ip != Config.bosh_ip
            Config.bosh_ip = ip
            logger.info("discovered bosh ip=#{Config.bosh_ip}")
          end
        end

        super
      end

      def service_ip
        cloud.ec2.instances[state.vm_cid].private_ip_address
      end

      private

      # TODO this code is simliar to has_stemcell_copy?
      # move the two into bosh_common later
      def has_aws_registry?(path=ENV['PATH'])
        path.split(":").each do |dir|
          return true if File.exist?(File.join(dir, "aws_registry"))
        end
        false
      end

      def migrate(db)
        db.create_table :aws_instances do
          primary_key :id
          column :instance_id, :text, :unique => true, :null => false
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
