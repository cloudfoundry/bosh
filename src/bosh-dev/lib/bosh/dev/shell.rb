module Bosh::Dev
  class Shell
    def initialize(stdout = $stdout)
      @stdout = stdout
    end

    def run(command, options = {})
      output_lines = run_command(command, options)
      output_lines = tail(output_lines, options)

      command_output = output_lines.join("\n")
      report(command, command_output, options)
      command_output
    end

    private

    attr_reader :stdout

    def run_command(command, options)
      stdout.puts command if options[:output_command]
      lines = []

      if options[:env]
        # Wrap in a shell because existing api to Shell#run takes a string
        # which makes it really hard to pass it to popen with custom environment.
         popen_args = [options[:env], ENV['SHELL'] || 'bash', '-c', command]
      else
        popen_args = command
      end

      io = IO.popen(popen_args)
      io.each do |line|
        stdout.puts line.chomp
        lines << line.chomp
      end

      io.close

      lines
    end

    def tail(lines, options)
      line_number = options[:last_number]
      line_number ? lines.last(line_number) : lines
    end

    def report(cmd, command_output, options)
      return if command_exited_successfully?

      redacted_cmd = cmd
      if options[:redact]
        redacted_cmd = redacted_cmd.gsub(/#{options[:redact].join('|')}/, "[REDACTED]")
      end

      err_msg = "Failed: '#{redacted_cmd}' from #{pwd}, with exit status #{$?.to_i}\n\n #{command_output}"
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
