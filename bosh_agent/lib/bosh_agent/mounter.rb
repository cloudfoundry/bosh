require 'bosh_agent'

module Bosh::Agent
  class Mounter
    def initialize(logger, shell_runner=Bosh::Exec)
      @logger = logger
      @shell_runner = shell_runner
    end

    def mount(device, mount_point, options)
      partition = "#{device}1"

      @logger.info("Mounting: #{partition} #{mount_point}")
      results = shell_runner.sh("mount #{options} #{partition} #{mount_point}", on_error: :return)

      if results.failed?
        raise Bosh::Agent::MessageHandlerError,
              "Failed to mount: '#{partition}' '#{mount_point}' Exit status: #{results.exit_status} Output: #{results.output}"
      end
    end

    private

    attr_reader :shell_runner
  end
end
