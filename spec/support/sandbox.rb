require 'benchmark'

module Bosh
  module Spec
    class Sandbox
      DIRECTOR_UUID = "deadbeef"

      DB_PATH = "director.sqlite"
      LOGS_PATH = "logs"
      DNS_DB_PATH = "director-dns.sqlite"
      DIRECTOR_TMP_PATH = "boshdir"
      TASK_LOGS_DIR = "boshdir/tasks"

      DIRECTOR_CONF_TEMPLATE = File.join(ASSETS_DIR, "director_test.yml.erb")

      BLOBSTORE_CONF_TEMPLATE = File.join(ASSETS_DIR, "blobstore_server.yml.erb")

      HM_CONFIG = "health_monitor.yml"
      HM_CONF_TEMPLATE = File.join(ASSETS_DIR, "health_monitor.yml.erb")

      REDIS_CONFIG = "redis_test.conf"
      REDIS_CONF_TEMPLATE = File.join(ASSETS_DIR, "redis_test.conf.erb")

      DIRECTOR_PID = "director.pid"
      WORKER_PID = "worker.pid"
      SCHEDULER_PID = "scheduler.pid"
      BLOBSTORE_PID = "blobstore.pid"
      NATS_PID = "nats.pid"
      HM_PID = "health_monitor.pid"
      REDIS_PID = "redis.pid"

      DIRECTOR_PATH = File.expand_path("../../../director", __FILE__)
      MIGRATIONS_PATH = File.join(DIRECTOR_PATH, "db", "migrations")

      TESTCASE_SQLITE_DB = "director.sqlite"

      attr_accessor :director_fix_stateful_nodes

      def pick_unique_name(name)
        @used_names ||= Set.new
        name = name.downcase.gsub(/[^a-z0-9]/, "_")
        if @used_names.include?(name)
          counter = 1
          original_name = name
          loop do
            name = "#{original_name}-#{counter}"
            break unless @user_names.include?(name)
          end
        end
        name
      end

      def director_config
        sandbox_path("director_test.yml")
      end

      def hm_config
        sandbox_path(HM_CONFIG)
      end

      def redis_config
        sandbox_path(REDIS_CONFIG)
      end

      def blobstore_config
        sandbox_path("blobstore_server.yml")
      end

      def db_path
        sandbox_path(DB_PATH)
      end

      def dns_db_path
        sandbox_path(DNS_DB_PATH)
      end

      def director_tmp_path
        sandbox_path(DIRECTOR_TMP_PATH)
      end

      def task_logs_dir
        sandbox_path(TASK_LOGS_DIR)
      end

      def agent_tmp_path
        cloud_storage_dir
      end

      def testcase_sqlite_db
        sandbox_path(TESTCASE_SQLITE_DB)
      end

      def logs_path
        sandbox_path(LOGS_PATH)
      end

      def director_pid
        sandbox_path(DIRECTOR_PID)
      end

      def worker_pid
        sandbox_path(WORKER_PID)
      end

      def scheduler_pid
        sandbox_path(SCHEDULER_PID)
      end

      def blobstore_pid
        sandbox_path(BLOBSTORE_PID)
      end

      def nats_pid
        sandbox_path(NATS_PID)
      end

      def hm_pid
        sandbox_path(HM_PID)
      end

      def redis_pid
        sandbox_path(REDIS_PID)
      end

      def sandbox_path(path)
        File.join(sandbox_root, path)
      end

      def start
        setup_sandbox_root

        @sqlite_db = sandbox_path("director.db")
        FileUtils.rm_rf(testcase_sqlite_db)

        Dir.chdir(DIRECTOR_PATH) do
          output = `bin/migrate -c #{director_config}`
          unless $?.exitstatus == 0
            puts "Failed to run migration:"
            puts output
            exit 1
          end
        end

        FileUtils.mkdir_p(cloud_storage_dir)

        FileUtils.rm_rf(logs_path)
        FileUtils.mkdir_p(logs_path)

        blobstore_output = "#{logs_path}/blobstore.out"

        FileUtils.cp(testcase_sqlite_db, @sqlite_db)

        raise "Please install redis on this machine" unless system("which redis-server > /dev/null")
        run_with_pid(%W[redis-server #{redis_config}], redis_pid)
        run_with_pid(%W[simple_blobstore_server -c #{blobstore_config}], blobstore_pid, output: blobstore_output)
        start_nats

        tries = 0
        while true
          tries += 1
          begin
            Redis.new(:host => "localhost", :port => redis_port).info
            break
          rescue Errno::ECONNREFUSED => e
            raise e if tries >= 20
            sleep(0.1)
          end
        end
      end

      def reset(name)
        time = Benchmark.realtime do
          do_reset(name)
        end
        puts "Reset took #{time} seconds"
      end

      def do_reset(name)
        kill_process(worker_pid, "QUIT")
        kill_process(director_pid)
        kill_process(hm_pid)
        kill_agents

        Redis.new(:host => "localhost", :port => redis_port).flushdb

        FileUtils.cp(@sqlite_db, testcase_sqlite_db)

        @name = pick_unique_name(name)

        FileUtils.rm_rf(blobstore_storage_dir)
        FileUtils.mkdir_p(blobstore_storage_dir)

        FileUtils.rm_rf(director_tmp_path)
        FileUtils.mkdir_p(director_tmp_path)

        File.open(File.join(director_tmp_path, "state.json"), "w") do |f|
          f.write(Yajl::Encoder.encode({"uuid" => DIRECTOR_UUID}))
        end

        @director_port = nil
        @hm_port = nil

        write_in_sandbox("director_test.yml", load_config_template(DIRECTOR_CONF_TEMPLATE))
        write_in_sandbox(HM_CONFIG, load_config_template(HM_CONF_TEMPLATE))

        run_with_pid(%W[director -c #{director_config}], director_pid, :output => director_output_path)
        run_with_pid(%W[worker -c #{director_config}], worker_pid, :output => worker_output_path, :env => {"QUEUE" => "*"})

        tries = 0
        loop do
          `lsof -w -i :#{director_port} | grep LISTEN`
          break if $?.exitstatus == 0
          tries += 1
          raise "could not connect to director on port #{director_port}" if tries > 50
          #sleep(0.2)
          sleep(1)
        end
      end

      def director_output_path
        "#{base_log_path}.director.out"
      end

      def worker_output_path
        "#{base_log_path}.worker.out"
      end

      def base_log_path
        File.join(logs_path, @name)
      end

      def reconfigure_director
        kill_process(director_pid)
        director_output = "#{base_log_path}.director.out"
        write_in_sandbox("director_test.yml", load_config_template(DIRECTOR_CONF_TEMPLATE))
        run_with_pid(%W[director -c #{director_config}], director_pid, :output => director_output)
      end

      def start_healthmonitor
        hm_output = "#{logs_path}/health_monitor.out"
        run_with_pid(%W[health_monitor -c #{hm_config}], hm_pid, :output => hm_output)
      end

      def blobstore_storage_dir
        sandbox_path("bosh_test_blobstore")
      end

      def cloud_storage_dir
        sandbox_path("bosh_cloud_test")
      end

      def save_task_logs(name)
        return unless ENV['DEBUG']

        if File.directory?(task_logs_dir)
          task_name = pick_unique_name("task_#{name}")
          FileUtils.mv(task_logs_dir, File.join(logs_path, task_name))
        end
      end

      def stop
        kill_agents
        kill_process(scheduler_pid)
        kill_process(worker_pid)
        kill_process(director_pid)
        kill_process(blobstore_pid)
        kill_process(redis_pid)
        kill_process(nats_pid)
        kill_process(hm_pid)
        FileUtils.rm_f(@sqlite_db)
        FileUtils.rm_f(db_path)
        FileUtils.rm_f(dns_db_path)
        FileUtils.rm_rf(director_tmp_path)
        FileUtils.rm_rf(agent_tmp_path)
        FileUtils.rm_rf(blobstore_storage_dir)
      end

      def start_nats
        run_with_pid(%W[nats-server -p #{nats_port}], nats_pid)
      end

      def start_scheduler
        run_with_pid(%W[director_scheduler -c #{director_config}], scheduler_pid)
      end

      def stop_nats
        kill_process(nats_pid)
      end

      def nats_port
        @nats_port ||= get_free_port
      end

      def hm_port
        @hm_port ||= get_free_port
      end

      def blobstore_port
        @blobstore_port ||= get_free_port
      end

      def director_port
        @director_port ||= get_free_port
      end

      def redis_port
        @redis_port ||= get_free_port
      end

      def sandbox_root
        unless @sandbox_root
          @sandbox_root = Dir.mktmpdir
          puts "sandbox root: #{@sandbox_root}"
        end
        @sandbox_root
      end

      def kill_agents
        Dir[File.join(agent_tmp_path, "running_vms", "*")].each do |vm|
          begin
            agent_pid = File.basename(vm).to_i
            Process.kill("INT", -1 * agent_pid) # Kill the whole process group
          rescue Errno::ESRCH
            puts "Running VM found but no agent with #{agent_pid} is running"
          end
        end
      end

      def run_with_pid(cmd_array, pidfile, opts = {})
        env = ENV.to_hash.merge(opts.fetch(:env, {}))
        output = opts.fetch(:output, :close)

        unless process_running?(pidfile)
          pid = Process.spawn(env, *cmd_array, out: output, err: output, in: :close)

          Process.detach(pid)
          File.open(pidfile, "w") { |f| f.write(pid) }

          tries = 0

          while !process_running?(pidfile)
            tries += 1
            raise RuntimeError, "Cannot run '#{cmd}' with #{env.inspect}" if tries > 20
            sleep(0.1)
          end
        end
      end

      def process_running?(pidfile)
        begin
          File.exists?(pidfile) && Process.kill(0, File.read(pidfile).to_i)
        rescue Errno::ESRCH
          FileUtils.rm pidfile
          false
        end
      end

      def kill_process(pidfile, signal="TERM")
        return unless process_running?(pidfile)
        pid = File.read(pidfile).to_i

        Process.kill(signal, pid)
      rescue Errno::ESRCH
        puts "Not found process with PID=#{pid} (pidfile #{pidfile})"
      ensure
        FileUtils.rm_rf pidfile
      end

      def setup_sandbox_root
        director_config = load_config_template(DIRECTOR_CONF_TEMPLATE)
        blobstore_config = load_config_template(BLOBSTORE_CONF_TEMPLATE)
        hm_config = load_config_template(HM_CONF_TEMPLATE)
        redis_config = load_config_template(REDIS_CONF_TEMPLATE)

        write_in_sandbox("director_test.yml", director_config)
        write_in_sandbox(HM_CONFIG, hm_config)
        write_in_sandbox("blobstore_server.yml", blobstore_config)
        write_in_sandbox(REDIS_CONFIG, redis_config)

        FileUtils.mkdir_p(sandbox_path('redis'))
        FileUtils.mkdir_p(blobstore_storage_dir)
      end

      def write_in_sandbox(filename, contents)
        Dir.chdir(sandbox_root) do
          File.open(filename, "w+") do |f|
            f.write(contents)
          end
        end
      end

      def load_config_template(filename)
        template_contents = File.read(filename)
        template = ERB.new(template_contents)

        template.result(binding)
      end

      def get_free_port
        socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        socket.bind(Addrinfo.tcp("127.0.0.1", 0))
        port = socket.local_address.ip_port
        socket.close
        # race condition, but good enough for now
        port
      end
    end
  end
end