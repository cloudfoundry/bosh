require 'bosh/dev/bat'

module Bosh::Dev::Bat
  class Shell
    def initialize(stdout = $stdout)
      @stdout = stdout
    end

    def run(command, options = {})
      output_lines = run_command(command)
      output_lines = tail(output_lines, options)

      command_output = output_lines.join("\n")
      report(command, command_output, options)
      command_output
    end

    private

    attr_reader :stdout

    def run_command(command)
      lines = []

      IO.popen(command).each do |line|
        stdout.puts line.chomp
        lines << line.chomp
      end.close

      lines
    end

    def tail(lines, options)
      line_number = options[:last_number]
      line_number ? lines.last(line_number) : lines
    end

    def report(cmd, command_output, options)
      return if command_exited_successfully?

      err_msg = "Failed: '#{cmd}' from #{pwd}, with exit status #{$?.to_i}\n\n #{command_output}"
      options[:ignore_failures] ? stdout.puts("#{err_msg}, continuing anyway") : raise(err_msg)
    end

    def command_exited_successfully?
      $?.success?
    end

    def pwd
      Dir.pwd
    rescue Errno::ENOENT
      'a deleted directory'
    end
  end
end
