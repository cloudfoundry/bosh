
module Bosh::Agent

  # A good chunk of this code is lifted from the implementation of POSIX::Spawn::Child
  class Monit
    BUFSIZE = (32 * 1024)

    def self.start
      self.new.run
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
          @logger.info("Monit: #{buf}")
        end
        out, err = '', ''
      end

    end

  end
end
