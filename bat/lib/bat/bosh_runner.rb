require 'common/exec'

module Bat
  class BoshRunner
    DEFAULT_POLL_INTERVAL = 1

    def initialize(executable, cli_config_path, logger)
      @executable = executable
      @cli_config_path = cli_config_path
      @logger = logger
    end

    def bosh(arguments, options = {})
      poll_interval = options[:poll_interval] || DEFAULT_POLL_INTERVAL

      command = "#{@executable} --non-interactive " +
        "-P #{poll_interval} " +
        "--config #{@cli_config_path} " +
        '--user admin --password admin ' +
        "#{arguments} 2>&1"

      begin
        @logger.info("Running bosh command --> #{command}")
        result = Bosh::Exec.sh(command, options)
      rescue Bosh::Exec::Error => e
        @logger.info("Bosh command failed: #{e.output}")
        raise
      end

      @logger.info(result.output)
      yield result if block_given?

      result
    end

    def bosh_safe(command, options = {})
      bosh(command, options.merge(on_error: :return))
    end
  end
end
