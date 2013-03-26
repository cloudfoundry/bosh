module Bosh
  module Spec
    class Sandbox

      LOGS_PATH   = File.join(ASSETS_DIR, "logs")
      REDIS_CONF  = File.join(ASSETS_DIR, "redis_test.conf")
      REDIS_PID   = File.join(ASSETS_DIR, "redis.pid")

      NATS_PORT = 42112
      DIRECTOR_UUID = "deadbeef"

      DB_PATH             = "/tmp/director.sqlite"
      DNS_DB_PATH         = "/tmp/director-dns.sqlite"
      DIRECTOR_TMP_PATH   = "/tmp/boshdir"
      TASK_LOGS_DIR       = "/tmp/boshdir/tasks"
      AGENT_TMP_PATH      = "/tmp/bosh_test_cloud"

      DIRECTOR_CONF  = File.join(ASSETS_DIR, "director_test.yml")
      BLOBSTORE_CONF = File.join(ASSETS_DIR, "blobstore_server.yml")
      HM_CONF        = File.join(ASSETS_DIR, "health_monitor.yml")

      DIRECTOR_PID  = File.join(ASSETS_DIR, "director.pid")
      WORKER_PID    = File.join(ASSETS_DIR, "worker.pid")
      BLOBSTORE_PID = File.join(ASSETS_DIR, "blobstore.pid")
      NATS_PID      = File.join(ASSETS_DIR, "nats.pid")
      HM_PID        = File.join(ASSETS_DIR, "health_monitor.pid")

      DIRECTOR_PATH   = File.expand_path("../../../director", __FILE__)
      MIGRATIONS_PATH = File.join(DIRECTOR_PATH, "db", "migrations")

      BLOBSTORE_STORAGE_DIR = "/tmp/bosh_test_blobstore"
      TESTCASE_SQLITE_DB = "/tmp/director.sqlite"

      class << self

        def pick_unique_name(name)
          @used_names ||= Set.new
          name = name.downcase.gsub(/[^a-z0-9]/, "_")
          if @used_names.include?(name)
            counter = 1
            original_name = name
            loop do
              name = "#{original_name}-#{counter}"
              break unless @userd_names.include?(name)
            end
          end
          name
        end

        def start
          @sqlite_db = File.join(ASSETS_DIR, "director.db")
          FileUtils.rm_rf(TESTCASE_SQLITE_DB)

          Dir.chdir(DIRECTOR_PATH) do
            output = `bundle exec bin/migrate -c #{DIRECTOR_CONF}`
            unless $?.exitstatus == 0
              puts "Failed to run migration:"
              puts output
              exit 1
            end
          end

          FileUtils.cp(TESTCASE_SQLITE_DB, @sqlite_db)

          raise "Please install redis on this machine" unless system("which redis-server > /dev/null")
          run_with_pid("redis-server #{REDIS_CONF}", REDIS_PID)
          run_with_pid("simple_blobstore_server -c #{BLOBSTORE_CONF}", BLOBSTORE_PID)
          start_nats

          if ENV["DEBUG"]
            FileUtils.rm_rf(LOGS_PATH)
            FileUtils.mkdir_p(LOGS_PATH)
          end

          tries = 0
          while true
            tries += 1
            begin
              Redis.new(:host => "localhost", :port => 63795).info
              break
            rescue Errno::ECONNREFUSED => e
              raise e if tries >= 20
              sleep(0.1)
            end
          end

        end

        def reset(name)
          kill_process(WORKER_PID, "QUIT")
          kill_process(DIRECTOR_PID)
          kill_process(HM_PID)
          kill_agents

          Redis.new(:host => "localhost", :port => 63795).flushdb

          FileUtils.cp(@sqlite_db, TESTCASE_SQLITE_DB)

          if ENV['DEBUG']
            name = pick_unique_name(name)
            base_log_path = File.join(LOGS_PATH, name)
            director_output = "#{base_log_path}.director.out"
            worker_output = "#{base_log_path}.worker.out"
            hm_output = "#{base_log_path}.health_monitor.out"
          else
            director_output = worker_output = hm_output = "/dev/null"
          end

          FileUtils.rm_rf(DIRECTOR_TMP_PATH)
          FileUtils.mkdir_p(DIRECTOR_TMP_PATH)

          File.open(File.join(DIRECTOR_TMP_PATH, "state.json"), "w") do |f|
            f.write(Yajl::Encoder.encode({"uuid" => DIRECTOR_UUID}))
          end

          run_with_pid("director -c #{DIRECTOR_CONF}", DIRECTOR_PID, :output => director_output)
          run_with_pid("worker -c #{DIRECTOR_CONF}", WORKER_PID, :output => worker_output, :env => {"QUEUE" => "*"})
          sleep(0.5) # Need to give the director time to come up before health_monitor tries to query it
          run_with_pid("health_monitor -c #{HM_CONF}", HM_PID, :output => hm_output)

          loop do
            `lsof -w -i :57523 | grep LISTEN`
            break if $?.exitstatus == 0
            sleep(0.5)
          end
        end

        def save_task_logs(name)
          return unless ENV['DEBUG']

          if File.directory?(TASK_LOGS_DIR)
            task_name = pick_unique_name("task_#{name}")
            FileUtils.mv(TASK_LOGS_DIR, File.join(LOGS_PATH, task_name))
          end
        end

        def stop
          kill_agents
          kill_process(WORKER_PID)
          kill_process(DIRECTOR_PID)
          kill_process(BLOBSTORE_PID)
          kill_process(REDIS_PID)
          kill_process(NATS_PID)
          kill_process(HM_PID)
          FileUtils.rm_f(@sqlite_db)
          FileUtils.rm_f(DB_PATH)
          FileUtils.rm_f(DNS_DB_PATH)
          FileUtils.rm_rf(DIRECTOR_TMP_PATH)
          FileUtils.rm_rf(AGENT_TMP_PATH)
          FileUtils.rm_rf(BLOBSTORE_STORAGE_DIR)
        end

        def start_nats
          run_with_pid("nats-server -p #{NATS_PORT}", NATS_PID)
        end

        private

        def kill_agents
          Dir[File.join(AGENT_TMP_PATH, "running_vms", "*")].each do |vm|
            begin
              agent_pid = File.basename(vm).to_i
              Process.kill("INT", -1 * agent_pid) # Kill the whole process group
            rescue Errno::ESRCH
              puts "Running VM found but no agent with #{agent_pid} is running"
            end
          end
        end

        def run_with_pid(cmd, pidfile, opts = {})
          env = opts[:env] || {}
          output = opts[:output] || "/dev/null"

          unless process_running?(pidfile)
            pid = fork do
              $stdin.reopen("/dev/null")
              [ $stdout, $stderr ].each { |stream| stream.reopen(output, "w") }
              env.each_pair { |k, v| ENV[k] = v }
              exec cmd
            end

            Process.detach(pid)
            File.open(pidfile, "w") { |f| f.write(pid) }

            tries = 0

            while !process_running?(pidfile)
              tries += 1
              raise RuntimeError, "Cannot run '#{cmd}' with #{env.inspect}" if tries > 5
              sleep(1)
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
          sleep(1) while process_running?(pidfile)

        rescue Errno::ESRCH
          puts "Not found process with PID=#{pid} (pidfile #{pidfile})"
        ensure
          FileUtils.rm_rf pidfile
        end
      end

    end
  end
end
