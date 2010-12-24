require "fileutils"
require "tempfile"

module Bosh
  module Spec
    class Sandbox

      ASSETS_PATH = File.expand_path("../assets", __FILE__)
      REDIS_CONF  = File.join(ASSETS_PATH, "redis_test.conf")
      REDIS_PID   = File.join(ASSETS_PATH, "redis_db/redis.pid")

      DIRECTOR_CONF  = File.join(ASSETS_PATH, "director_test.yml")
      BLOBSTORE_CONF = File.join(ASSETS_PATH, "blobstore_server.yml")
      
      DIRECTOR_PID  = File.join(ASSETS_PATH, "director.pid")
      WORKER_PID    = File.join(ASSETS_PATH, "worker.pid")
      BLOBSTORE_PID = File.join(ASSETS_PATH, "blobstore.pid")

      DIRECTOR_PATH  = File.expand_path("../../director", __FILE__)
      BLOBSTORE_PATH = File.expand_path("../../simple_blobstore_server", __FILE__)

      def self.start
        new.start
      end

      def self.stop
        new.stop
      end

      def start
        director_env  = { "BUNDLE_GEMFILE" => "#{DIRECTOR_PATH}/Gemfile" }
        blobstore_env = { "BUNDLE_GEMFILE" => "#{BLOBSTORE_PATH}/Gemfile" }
        worker_env   = director_env.merge("QUEUE" => "*")

        run_with_pid("redis-server #{REDIS_CONF}", REDIS_PID)
        run_with_pid("#{DIRECTOR_PATH}/bin/director -c #{DIRECTOR_CONF}", DIRECTOR_PID, director_env)
        run_with_pid("#{DIRECTOR_PATH}/bin/worker -c #{DIRECTOR_CONF}", WORKER_PID, worker_env)
        run_with_pid("#{BLOBSTORE_PATH}/bin/simple_blobstore_server -c #{BLOBSTORE_CONF}", BLOBSTORE_PID, blobstore_env)

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

      def stop
        kill_process(WORKER_PID, "QUIT")
        kill_process(DIRECTOR_PID)
        kill_process(BLOBSTORE_PID)        
        kill_process(REDIS_PID)
      end
      
      private

      def run_with_pid(cmd, pidfile, env = {})
        unless process_running?(pidfile)

          pid = fork do
            [ $stdout, $stdin, $stderr ].each { |stream| stream.reopen("/dev/null") } # closing fds leads to problems with worker
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

      def kill_process(pidfile, signal="INT")
        pid = File.read(pidfile).to_i
        
        while process_running?(pidfile)
          Process.kill signal, pid
          sleep(0.1)
        end

      rescue Errno::ESRCH
        puts "Not found process with PID=#{pid}"
      ensure
        FileUtils.rm_rf pidfile        
      end

    end
  end
end
