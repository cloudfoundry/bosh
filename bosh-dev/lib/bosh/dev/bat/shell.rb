require 'bosh/dev/bat'

module Bosh::Dev::Bat
  class Shell
    def initialize(stdout = $stdout)
      @stdout = stdout
    end

    def run(cmd, options = {})
      lines = []

      IO.popen(cmd).each do |line|
        stdout.puts line.chomp
        lines << line.chomp
      end.close # force the process to close so that $? is set

      if options[:last_number]
        line_number = options[:last_number]
        line_number = lines.size if lines.size < options[:last_number]
        cmd_out = lines[-line_number..-1].join("\n")
      else
        cmd_out = lines.join("\n")
      end

      unless $?.success?
        pwd = Dir.pwd rescue 'a deleted directory'
        err_msg = "Failed: '#{cmd}' from #{pwd}, with exit status #{$?.to_i}\n\n #{cmd_out}"

        if options[:ignore_failures]
          stdout.puts("#{err_msg}, continuing anyway")
        else
          raise(err_msg)
        end
      end
      cmd_out
    end

    private
    attr_reader :stdout
  end
end
