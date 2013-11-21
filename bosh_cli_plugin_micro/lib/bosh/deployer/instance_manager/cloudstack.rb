# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.
# Copyright (c) 2012 ZJU Cloud Computing, Inc.

module Bosh::Deployer
  class InstanceManager
    class Cloudstack < InstanceManager

      def update_spec(spec)
        properties = spec.properties

        properties['cloudstack'] =
          Config.spec_properties['cloudstack'] ||
          Config.cloud_options['properties']['cloudstack'].dup

        properties['cloudstack']['registry'] = Config.cloud_options['properties']['registry']
        properties['cloudstack']['stemcell'] = Config.cloud_options['properties']['stemcell']

        spec.delete('networks')
      end

      # rubocop:disable MethodLength
      def configure
        properties = Config.cloud_options['properties']
        @ssh_user = properties['cloudstack']['ssh_user']
        @ssh_port = properties['cloudstack']['ssh_port'] || 22
        @ssh_wait = properties['cloudstack']['ssh_wait'] || 60

        key = properties['cloudstack']['private_key']
        err 'Missing properties.cloudstack.private_key' unless key
        @ssh_key = File.expand_path(key)
        unless File.exists?(@ssh_key)
          err "properties.cloudstack.private_key '#{key}' does not exist"
        end

        uri = URI.parse(properties['registry']['endpoint'])
        user, password = uri.userinfo.split(':', 2)
        @registry_port = uri.port

        @registry_db = Tempfile.new('bosh_registry_db')
        @registry_connection_settings = {
            'adapter' => 'sqlite',
            'database' => @registry_db.path
        }

        registry_config = {
          'logfile' => './bosh-registry.log',
          'http' => {
            'port' => uri.port,
            'user' => user,
            'password' => password
          },
          'db' => @registry_connection_settings,
          'cloud' => {
            'plugin' => 'cloudstack',
            'cloudstack' => properties['cloudstack']
          }
        }

        @registry_config = Tempfile.new('bosh_registry_yml')
        @registry_config.write(Psych.dump(registry_config))
        @registry_config.close
      end
      # rubocop:enable MethodLength

      # rubocop:disable MethodLength
      def start
        configure

        Sequel.connect(@registry_connection_settings) do |db|
          migrate(db)
          instances = @deployments['registry_instances']
          db[:registry_instances].insert_multiple(instances) if instances
        end

        unless has_bosh_registry?
          err 'bosh-registry command not found - ' +
            "run 'gem install bosh-registry'"
        end

        cmd = "bosh-registry -c #{@registry_config.path}"

        @registry_pid = spawn(cmd)

        5.times do
          sleep 0.5
          if Process.waitpid(@registry_pid, Process::WNOHANG)
            err "`#{cmd}` failed, exit status=#{$?.exitstatus}"
          end
        end

        timeout_time = Time.now.to_f + (60 * 5)
        http_client = HTTPClient.new
        begin
          http_client.head("http://127.0.0.1:#{@registry_port}")
          sleep 0.5
        rescue URI::Error, SocketError, Errno::ECONNREFUSED, HTTPClient::ReceiveTimeoutError => e
          if timeout_time - Time.now.to_f > 0
            retry
          else
            err "Cannot access bosh-registry: #{e.message}"
          end
        end

        logger.info("bosh-registry is ready on port #{@registry_port}")
      ensure
        @registry_config.unlink if @registry_config
      end
      # rubocop:enable MethodLength

      def stop
        if @registry_pid && process_exists?(@registry_pid)
          Process.kill('INT', @registry_pid)
          Process.waitpid(@registry_pid)
        end

        return unless @registry_connection_settings

        Sequel.connect(@registry_connection_settings) do |db|
          @deployments['registry_instances'] = db[:registry_instances].map { |row| row }
        end

        save_state
        @registry_db.unlink if @registry_db
      end

      def discover_bosh_ip
        if exists?
          server = cloud.compute.servers.get(state.vm_cid)

          floating_ip = cloud.compute.ipaddresses.find {
              |addr| addr.virtual_machine_id == server.id
          }
          ip = floating_ip.nil? ? service_ip : floating_ip.ip_address
          err 'Unable to discover bosh ip' if ip.nil?

          if ip != Config.bosh_ip
            Config.bosh_ip = ip
            logger.info("discovered bosh ip=#{Config.bosh_ip}")
          end
        end

        super
      end

      def service_ip
        server = cloud.compute.servers.get(state.vm_cid)

        ip = server.nics.first['ipaddress']

        err 'Unable to discover service ip' if ip.nil?
        ip
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        # CloudStack stores disk size in GiB but we work with MiB
        cloud.compute.volumes.get(cid).size * 1024
      end

      def persistent_disk_changed?
        # since CloudStack stores disk size in GiB and we use MiB there
        # is a risk of conversion errors which lead to an unnecessary
        # disk migration, so we need to do a double conversion
        # here to avoid that
        requested = (Config.resources['persistent_disk'] / 1024.0).ceil * 1024
        requested != disk_size(state.disk_cid)
      end

      private

      def has_bosh_registry?(path = ENV['PATH'])
        path.split(File::PATH_SEPARATOR).each do |dir|
          return true if File.exist?(File.join(dir, 'bosh-registry'))
        end
        false
      end

      def migrate(db)
        db.create_table :registry_instances do
          primary_key :id
          column :instance_id, :text, unique: true, null: false
          column :settings, :text, null:  false
        end
      end

    end
  end
end
