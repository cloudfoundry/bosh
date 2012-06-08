require "open4" unless defined?(::Open4)

module Bosh::Exec::Adapters
  # execute a command using the open4 gem
  class Open4
    def self.sh(command)
      out = nil
      err = nil
      status = ::Open4::popen4(command) do |pid, stdin, stdout, stderr|
        out = stdout.read.strip
        err = stderr.read.strip
      end
puts "status = #{status.inspect}"
      Bosh::Exec::Result.new(command, out, err, status.exitstatus)
    end
  end
end
