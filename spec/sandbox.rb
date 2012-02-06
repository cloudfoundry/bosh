module Bosh
  module Spec
    class Sandbox

      ASSETS_PATH = File.expand_path("../assets", __FILE__)
      LOGS_PATH   = File.join(ASSETS_PATH, "logs")
      REDIS_CONF  = File.join(ASSETS_PATH, "redis_test.conf")
      REDIS_PID   = File.join(ASSETS_PATH, "redis_db/redis.pid")

      NATS_PORT = 42112
      DIRECTOR_UUID = "deadbeef"

      DB_PATH             = "/tmp/director.sqlite"
      DNS_DB_PATH         = "/tmp/director-dns.sqlite"
      DIRECTOR_TMP_PATH   = "/tmp/boshdir"
      AGENT_TMP_PATH      = "/tmp/bosh_test_cloud"

      DIRECTOR_CONF  = File.join(ASSETS_PATH, "director_test.yml")
      BLOBSTORE_CONF = File.join(ASSETS_PATH, "blobstore_server.yml")
      HM_CONF        = File.join(ASSETS_PATH, "health_monitor.yml")

      DIRECTOR_PID  = File.join(ASSETS_PATH, "director.pid")
      WORKER_PID    = File.join(ASSETS_PATH, "worker.pid")
      BLOBSTORE_PID = File.join(ASSETS_PATH, "blobstore.pid")
      NATS_PID      = File.join(ASSETS_PATH, "nats.pid")
      HM_PID        = File.join(ASSETS_PATH, "health_monitor.pid")

      DIRECTOR_PATH   = File.expand_path("../../director", __FILE__)
      HM_PATH         = File.expand_path("../../health_monitor", __FILE__)
      BLOBSTORE_PATH  = File.expand_path("../../simple_blobstore_server", __FILE__)
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
          @sqlite_db = File.join(ASSETS_PATH, "director.db")
          FileUtils.rm_rf(TESTCASE_SQLITE_DB)

          Bundler.with_clean_env do
            Dir.chdir(DIRECTOR_PATH) do
              output = `BUNDLE_GEMFILE=#{DIRECTOR_PATH}/Gemfile bundle exec rake migration:run[#{DIRECTOR_CONF}] --trace`
              puts output unless $?.exitstatus == 0
            end

          end
          FileUtils.cp(TESTCASE_SQLITE_DB, @sqlite_db)

          blobstore_env = { "BUNDLE_GEMFILE" => "#{BLOBSTORE_PATH}/Gemfile" }

          run_with_pid("redis-server #{REDIS_CONF}", REDIS_PID)
          run_with_pid("#{BLOBSTORE_PATH}/bin/simple_blobstore_server -c #{BLOBSTORE_CONF}", BLOBSTORE_PID, :env => blobstore_env)

          run_with_pid("nats-server -p #{NATS_PORT}", NATS_PID)

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

          FileUtils.mkdir_p(DIRECTOR_TMP_PATH)

          File.open(File.join(DIRECTOR_TMP_PATH, "state.json"), "w") do |f|
            f.write(Yajl::Encoder.encode({"uuid" => DIRECTOR_UUID}))
          end

          director_env = { "BUNDLE_GEMFILE" => "#{DIRECTOR_PATH}/Gemfile" }
          worker_env   = director_env.merge("QUEUE" => "*")
          hm_env       = { "BUNDLE_GEMFILE" => "#{HM_PATH}/Gemfile" }

          run_with_pid("#{DIRECTOR_PATH}/bin/director -c #{DIRECTOR_CONF}", DIRECTOR_PID,
                       :output => director_output, :env => director_env)
          run_with_pid("#{DIRECTOR_PATH}/bin/worker -c #{DIRECTOR_CONF}", WORKER_PID,
                       :output => worker_output, :env => worker_env)
          run_with_pid("#{HM_PATH}/bin/health_monitor -c #{HM_CONF}", HM_PID,
                       :output => hm_output, :env => hm_env)

          loop do
            `lsof -i :57523 | grep LISTEN`
            break if $?.exitstatus == 0
            sleep(0.5)
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
