require 'sequel'
require 'sqlite3'

module Bosh::Deployer
  class Registry
    attr_reader :port

    def initialize(endpoint, cloud_plugin, cloud_properties, deployments, logger)
      @cloud_properties = cloud_properties
      @deployments = deployments
      @logger = logger

      uri = URI.parse(endpoint)
      @user, @password = uri.userinfo.split(':', 2)
      @port = uri.port
      @cloud_plugin = cloud_plugin
    end

    def start
      write_configure
      Sequel.connect(connection_settings) do |db|
        migrate(db)
        instances = deployments['registry_instances']
        db[:registry_instances].insert_multiple(instances) if instances
      end

      unless has_bosh_registry?
        err "bosh-registry command not found - run 'gem install bosh-registry'"
      end

      cmd = "bosh-registry -c #{@registry_config.path}"

      @registry_pid = Process.spawn(cmd)

      watch_for_crash(cmd)
      wait_for_listen

      logger.info("bosh-registry is ready on port #{port}")
    ensure
      @registry_config.unlink if @registry_config
    end

    def stop
      kill_registry if registry_pid

      return unless db_file

      Sequel.connect(connection_settings) do |db|
        deployments['registry_instances'] = db[:registry_instances].map { |row| row }
      end
    ensure
      db_file.unlink if db_file
    end

    RETRYABLE_HTTP_EXCEPTIONS = [
      URI::Error,
      SocketError,
      Errno::ECONNREFUSED,
      HTTPClient::ReceiveTimeoutError
    ]

    private

    attr_reader(
      :deployments,
      :cloud_properties,
      :logger,
      :user,
      :password,
      :cloud_plugin,
      :db_file,
      :registry_pid,
    )

    def watch_for_crash(cmd)
      5.times do
        Kernel.sleep 0.5
        _, status = Process.waitpid2(@registry_pid, Process::WNOHANG)
        if status
          err "`#{cmd}` failed, exit status=#{status.exitstatus}"
        end
      end
    end

    def wait_for_listen
      http_client = HTTPClient.new
      Bosh::Common.retryable(on: RETRYABLE_HTTP_EXCEPTIONS, sleep: 0.5, tries: 300) do
        http_client.head("http://127.0.0.1:#{port}")
      end

    rescue Bosh::Common::RetryCountExceeded => e
      err "Cannot access bosh-registry: #{e.message}"
    end

    def has_bosh_registry?(path = ENV.to_hash['PATH'])
      path.split(File::PATH_SEPARATOR).each do |dir|
        return true if File.exist?(File.join(dir, 'bosh-registry'))
      end
      false
    end

    def migrate(db)
      db.create_table :registry_instances do
        primary_key :id
        column :instance_id, :text, unique: true, null: false
        column :settings, :text, null: false
      end
    end

    def write_configure
      @db_file = Tempfile.new('bosh_registry_db')

      registry_config = {
        'logfile' => './bosh-registry.log',
        'http' => {
          'port' => port,
          'user' => user,
          'password' => password
        },
        'db' => connection_settings,
        'cloud' => {
          'plugin' => cloud_plugin,
          cloud_plugin => cloud_properties
        }
      }

      @registry_config = Tempfile.new('bosh_registry_yml')
      @registry_config.write(Psych.dump(registry_config))
      @registry_config.close
    end

    def connection_settings
      {
        'adapter' => 'sqlite',
        'database' => db_file.path
      }
    end

    def kill_registry
      Process.kill('INT', @registry_pid)
      Process.waitpid2(@registry_pid)
    rescue Errno::ESRCH
      logger.debug('registry already stopped')
    end
  end
end
