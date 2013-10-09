require 'bosh_agent'

module Bosh::Agent
  class Mounter
    def initialize(logger, shell_runner=Bosh::Exec)
      @logger = logger
      @shell_runner = shell_runner
    end

    def mount(partition, mount_point, options_hash={})
      @logger.info("Mounting: #{partition} #{mount_point}")
      options = build_command_line_options(options_hash)

      results = shell_runner.sh("mount #{options} #{partition} #{mount_point}", on_error: :return)

      if results.failed?
        raise Bosh::Agent::MessageHandlerError,
              "Failed to mount: '#{partition}' '#{mount_point}' Exit status: #{results.exit_status} Output: #{results.output}"
      end
    end

    private

    attr_reader :shell_runner

    def build_command_line_options(options_hash)
      command_options = { read_only: '-o ro' }
      commands = []

      command_options.each do |key,value|
        if options_hash[key]
          commands << value
          options_hash.delete(key)
        end
      end

      raise Bosh::Agent::Error, "Invalid options: #{options_hash.inspect}" unless options_hash.empty?

      commands.join(' ')
    end
  end
end
