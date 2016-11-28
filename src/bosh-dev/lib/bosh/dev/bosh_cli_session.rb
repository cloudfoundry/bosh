require 'bosh/dev'
require 'bosh/core/shell'
require 'common/retryable'
require 'tempfile'
require 'tmpdir'

module Bosh::Dev
  class BoshCliSession
    def self.default
      new(PathBoshCmd.new)
    end

    def initialize(bosh_cmd)
      @bosh_cmd = bosh_cmd
      @shell = Bosh::Core::Shell.new
    end

    def run_bosh(cmd, options = {})
      debug_on_fail = !!options.delete(:debug_on_fail)
      retryable     = options.delete(:retryable) || Bosh::Retryable.new

      bosh_command = "#{@bosh_cmd.cmd} -v -n -P 10 --config '#{bosh_config_path}' #{cmd}"

      # Print out command that's being run so that we now what CI is doing!
      puts bosh_command

      # Do not pass through unrelated options to the shell
      shell_options = { env: @bosh_cmd.env }
      shell_options[:last_number] = options[:last_number] if options[:last_number]

      retryable.retryer { shell.run(bosh_command, shell_options) }

    rescue RuntimeError
      run_bosh('task last --debug', last_number: 100, debug_on_fail: false) if debug_on_fail
      raise
    end

    def close
      @bosh_cmd.close
    end

    private

    attr_reader :shell

    def bosh_config_path
      # We should keep a reference to the tempfile, otherwise,
      # when the object gets GC'd, the tempfile is deleted.
      @bosh_config_tempfile ||= Tempfile.new('bosh_config')
      @bosh_config_tempfile.path
    end
  end

  class PathBoshCmd
    def cmd
      'bosh'
    end

    def env
      {}
    end

    def close
      # noop
    end
  end
end
