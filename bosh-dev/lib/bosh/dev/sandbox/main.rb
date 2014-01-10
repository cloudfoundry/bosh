require 'logger'
require 'benchmark'
require 'securerandom'
require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'
require 'bosh/dev/sandbox/database_migrator'
require 'bosh/dev/sandbox/postgresql'

module Bosh::Dev::Sandbox
  class Main
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    DIRECTOR_UUID = 'deadbeef'

    DIRECTOR_CONFIG = 'director_test.yml'
    DIRECTOR_CONF_TEMPLATE = File.join(ASSETS_DIR, 'director_test.yml.erb')

    REDIS_CONFIG = 'redis_test.conf'
    REDIS_CONF_TEMPLATE = File.join(ASSETS_DIR, 'redis_test.conf.erb')

    HM_CONFIG = 'health_monitor.yml'
    HM_CONF_TEMPLATE = File.join(ASSETS_DIR, 'health_monitor.yml.erb')

    DIRECTOR_PATH = File.expand_path('bosh-director', REPO_ROOT)
    MIGRATIONS_PATH = File.join(DIRECTOR_PATH, 'db', 'migrations')

    attr_reader :name
    attr_reader :health_monitor_process
    attr_reader :scheduler_process

    alias_method :db_name, :name
    attr_reader :blobstore_storage_dir
    attr_accessor :director_fix_stateful_nodes

    def initialize(logger = Logger.new(STDOUT))
      @logger = logger
      @name = SecureRandom.hex(6)

      @logs_path = sandbox_path('logs')
      @dns_db_path = sandbox_path('director-dns.sqlite')
      @task_logs_dir = sandbox_path('boshdir/tasks')
      @director_tmp_path = sandbox_path('boshdir')
      @blobstore_storage_dir = sandbox_path('bosh_test_blobstore')

      director_config = sandbox_path(DIRECTOR_CONFIG)
      base_log_path = File.join(logs_path, @name)

      @redis_process = Service.new(
        %W[redis-server #{sandbox_path(REDIS_CONFIG)}], {}, @logger)

      @redis_socket_connector = SocketConnector.new('localhost', redis_port, @logger)

      @nats_process = Service.new(%W[nats-server -p #{nats_port}], {}, @logger)

      @director_process = Service.new(
        %W[bosh-director -c #{director_config}],
        { output: "#{base_log_path}.director.out" },
        @logger,
      )

      @director_socket_connector = SocketConnector.new('localhost', director_port, @logger)

      @worker_process = Service.new(
        %W[bosh-director-worker -c #{director_config}],
        { output: "#{base_log_path}.worker.out", env: { 'QUEUE' => '*' } },
        @logger,
      )

      @health_monitor_process = Service.new(
        %W[bosh-monitor -c #{sandbox_path(HM_CONFIG)}],
        { output: "#{logs_path}/health_monitor.out" },
        @logger,
      )

      @scheduler_process = Service.new(
        %W[bosh-director-scheduler -c #{director_config}],
        { output: "#{base_log_path}.scheduler.out" },
        @logger,
      )

      @postgresql = Postgresql.new(sandbox_root, @name, @logger)

      @database_migrator = DatabaseMigrator.new(DIRECTOR_PATH, director_config, @logger)
    end

    def agent_tmp_path
      cloud_storage_dir
    end

    def sandbox_path(path)
      File.join(sandbox_root, path)
    end

    def start
      setup_sandbox_root

      @postgresql.create_db
      @database_migrator.migrate

      FileUtils.mkdir_p(cloud_storage_dir)
      FileUtils.rm_rf(logs_path)
      FileUtils.mkdir_p(logs_path)

      @redis_process.start
      @nats_process.start
      @redis_socket_connector.try_to_connect
    end

    def reset(name)
      time = Benchmark.realtime { do_reset(name) }
      @logger.info("Reset took #{time} seconds")
    end

    def reconfigure_director
      @director_process.stop
      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      @director_process.start
    end

    def cloud_storage_dir
      sandbox_path('bosh_cloud_test')
    end

    def save_task_logs(name)
      if ENV['DEBUG'] && File.directory?(task_logs_dir)
        task_name = "task_#{name}_#{SecureRandom.hex(6)}"
        FileUtils.mv(task_logs_dir, File.join(logs_path, task_name))
      end
    end

    def stop
      kill_agents
      @scheduler_process.stop
      @worker_process.stop
      @director_process.stop
      @redis_process.stop
      @nats_process.stop
      @health_monitor_process.stop
      @postgresql.drop_db
      FileUtils.rm_f(dns_db_path)
      FileUtils.rm_rf(director_tmp_path)
      FileUtils.rm_rf(agent_tmp_path)
      FileUtils.rm_rf(blobstore_storage_dir)
    end

    def run
      start
      @logger.info('Sandbox running, type ctrl+c to stop')

      loop { sleep 60 }

    # rubocop:disable HandleExceptions
    rescue Interrupt
    # rubocop:enable HandleExceptions
    ensure
      stop
      @logger.info('Stopped sandbox')
    end

    def nats_port
      @nats_port ||= get_named_port(:nats)
    end

    def hm_port
      @hm_port ||= get_named_port(:hm)
    end

    def director_port
      @director_port ||= get_named_port(:director)
    end

    def redis_port
      @redis_port ||= get_named_port(:redis)
    end

    def sandbox_root
      @sandbox_root ||= Dir.mktmpdir.tap { |p| @logger.info("sandbox=#{p}") }
    end

    private

    def do_reset(name)
      kill_agents
      @worker_process.stop('QUIT')
      @director_process.stop
      @health_monitor_process.stop

      Redis.new(host: 'localhost', port: redis_port).flushdb

      @postgresql.drop_db
      @postgresql.create_db
      @database_migrator.migrate

      FileUtils.rm_rf(blobstore_storage_dir)
      FileUtils.mkdir_p(blobstore_storage_dir)
      FileUtils.rm_rf(director_tmp_path)
      FileUtils.mkdir_p(director_tmp_path)

      File.open(File.join(director_tmp_path, 'state.json'), 'w') do |f|
        f.write(Yajl::Encoder.encode('uuid' => DIRECTOR_UUID))
      end

      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      write_in_sandbox(HM_CONFIG, load_config_template(HM_CONF_TEMPLATE))

      @director_process.start
      @worker_process.start

      # CI does not have enough time to start bosh-director
      # for some parallel tests; increasing to 40 secs (= 80 tries).
      @director_socket_connector.try_to_connect(80)
    end

    def kill_agents
      vm_ids = Dir.glob(File.join(agent_tmp_path, 'running_vms', '*')).map { |vm| File.basename(vm).to_i }
      vm_ids.each do |agent_pid|
        begin
          Process.kill('INT', agent_pid)
        rescue Errno::ESRCH
          @logger.info("Running VM found but no agent with #{agent_pid} is running")
        end
      end
    end

    def setup_sandbox_root
      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      write_in_sandbox(HM_CONFIG, load_config_template(HM_CONF_TEMPLATE))
      write_in_sandbox(REDIS_CONFIG, load_config_template(REDIS_CONF_TEMPLATE))
      FileUtils.mkdir_p(sandbox_path('redis'))
      FileUtils.mkdir_p(blobstore_storage_dir)
    end

    def write_in_sandbox(filename, contents)
      Dir.chdir(sandbox_root) do
        File.open(filename, 'w+') do |f|
          f.write(contents)
        end
      end
    end

    def load_config_template(filename)
      template_contents = File.read(filename)
      template = ERB.new(template_contents)
      template.result(binding)
    end

    def get_named_port(name)
      # I don't want to optimize for look-up speed, we only have 5 named ports anyway
      @port_names ||= []
      @port_names << name unless @port_names.include?(name)

      offset = @port_names.index(name)
      test_number = ENV['TEST_ENV_NUMBER'].to_i
      61000 + test_number * 100 + offset
    end

    attr_reader :logs_path, :director_tmp_path, :dns_db_path, :task_logs_dir
  end
end
