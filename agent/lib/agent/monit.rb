
module Bosh::Agent

  # A good chunk of this code is lifted from the implementation of POSIX::Spawn::Child
  class Monit
    BUFSIZE = (32 * 1024)

    def self.start
      self.new.run
    end

    class << self
      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def monit_user_file
        File.join(base_dir, 'monit', 'monit.user')
      end

      def monit_credentials
        entry = File.read(monit_user_file).lines.find { |line| line.match(/\A#{BOSH_APP_GROUP}/) }
        user, cred = entry.split(/:/)
        [user, cred.strip]
      end

      def monit_api_client
        user, cred = monit_credentials
        MonitApi::Client.new("http://#{user}:#{cred}@localhost:2822")
      end

      def random_credential
        OpenSSL::Random.random_bytes(8).unpack("H*")[0]
      end

      def setup_monit_user
        unless File.exist?(monit_user_file)
          File.open(monit_user_file, 'w') do |f|
            f.puts("vcap:#{random_credential}")
          end
        end
      end

    end

    def initialize
      @logger = Bosh::Agent::Config.logger
    end

    def run
      Thread.new {
        exec_monit
      }
    end

    def exec_monit
      pid, stdin, stdout, stderr = POSIX::Spawn.popen4('/usr/sbin/monit', '-I', '-c', '/etc/monit/monitrc')
      stdin.close

      log_monit_output(stdout, stderr)

      status = Process.waitpid(pid)
    rescue Object => e
      @logger.info("Failed to run Monit: #{e.inspect} #{e.backtrace}")
      [stdin, stdout, stderr].each { |fd| fd.close rescue nil }
      if status.nil?
        ::Process.kill('TERM', pid) rescue nil
        waitpid(pid)      rescue nil
      end
      raise
    ensure
      [stdin, stdout, stderr].each { |fd| fd.close rescue nil } 
    end

    def log_monit_output(stdout, stderr)
      timeout = nil
      out, err = '', ''
      readers = [stdout, stderr]
      writers = []

      while readers.any?
        ready = IO.select(readers, writers, readers + writers, timeout)
        ready[0].each do |fd|
          buf = (fd == stdout) ? out : err
          begin
            buf << fd.readpartial(BUFSIZE)
          rescue Errno::EAGAIN, Errno::EINTR
          rescue EOFError
            readers.delete(fd)
            fd.close
          end
          buf.gsub!(/\n\Z/,'')
          @logger.info("Monit: #{buf}")
        end
        out, err = '', ''
      end

    end

  end
end
